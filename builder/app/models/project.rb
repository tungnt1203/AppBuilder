class Project < ApplicationRecord
  RESERVED_SUBDOMAINS = %w[ www admin api app mail ]
  # The language the owner chats with the agent in (the builder itself and the apps are English).
  LANGUAGES = { "en" => { name: "English", time_zone: "UTC" }, "vi" => { name: "Tiếng Việt", time_zone: "Asia/Ho_Chi_Minh" } }

  # Optional only for apps made before there were accounts (see AddOwnerToProjects).
  belongs_to :owner, class_name: "User", optional: true
  has_many :messages, -> { order(:id) }, dependent: :destroy
  has_many :deployments, dependent: :destroy
  has_many :agent_commands, dependent: :delete_all
  has_many :usages, dependent: :nullify

  enum :status, %w[ setting_up ready working failed ].index_by(&:itself), default: "setting_up"
  enum :preview_status, %w[ starting running broken ].index_by(&:itself), prefix: :preview

  validates :name, presence: true
  validates :owner, presence: true, on: :create
  validate :owner_has_room, on: :create
  validates :language, inclusion: { in: LANGUAGES.keys }
  validates :subdomain, uniqueness: true, exclusion: { in: RESERVED_SUBDOMAINS, message: "is reserved" },
    format: { with: /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/, message: "can only use a-z, 0-9 and dashes, not at either end" }, allow_nil: true

  normalizes :subdomain, with: ->(subdomain) { subdomain.strip.downcase }

  before_validation :assign_slug, :assign_port, on: :create

  broadcasts_refreshes
  after_update_commit :broadcast_listing, if: -> { saved_change_to_status? || saved_change_to_preview_status? }
  after_destroy_commit -> { thumbnail.delete; broadcast_listing }

  scope :ordered, -> { order(updated_at: :desc) }
  # Apps built by bin/eval stay off the home page; its report links to them.
  scope :listed, -> { where(eval_run: nil) }

  def to_param
    slug
  end

  # Home pages showing this app: its owner's, and the administrators' list of every app.
  def broadcast_listing
    broadcast_refresh_later_to(owner, :projects) if owner
    broadcast_refresh_later_to(:projects)
  end

  # Without a name, the app is called after the start of the owner's request until
  # the setup job thinks of a real one (see #adopt_name).
  def name_after(request)
    return if name.present? || request.blank?

    words = request.squish.split
    self.name = words.first(4).join(" ").truncate(40, separator: " ") + (words.size > 4 ? "…" : "")
    self.name_pending = true
  end

  def adopt_name(new_name)
    update!(name: new_name.presence || name.delete_suffix("…"), name_pending: false)
  end

  def path
    Rails.configuration.x.projects_root.join(slug)
  end

  # Apps made since the template split the customers' site from /admin keep the owner's screens
  # and sign in under /admin; older apps have them at the root.
  def admin_area?
    path.join("app/controllers/admin/sessions_controller.rb").exist?
  end

  def staff_home_path
    admin_area? ? "/admin" : "/"
  end

  def staff_sign_in_path
    admin_area? ? "/admin/session/new" : "/session/new"
  end

  def preview_url
    "http://localhost:#{port}"
  end

  def preview
    PreviewServer.new(self)
  end

  def preview_gate
    PreviewGate.new(self)
  end

  # Brings the preview up on the current code: migrations and styles first, then a
  # fresh server, then a look at the home page. What went wrong is kept for the owner
  # (and the agent) instead of failing the step that called this.
  def restart_preview(restart: true)
    update!(preview_status: :starting, preview_error: nil)
    problem = prepare_preview
    begin
      restart ? preview.restart : preview.start
    rescue SystemCallError => error
      problem ||= "The preview server couldn't start: #{error.message}"
    end
    problem ||= preview.check
  rescue => error
    problem = "#{error.class}: #{error.message}"
    raise
  ensure
    update!(preview_status: problem ? :broken : :running, preview_error: problem&.truncate(4000), preview_version: preview_version + 1)
    ThumbnailJob.perform_later(self) unless problem
  end

  # Opening the studio starts a preview that isn't running, for example after the builder restarted.
  def ensure_preview
    return unless ready? || failed?
    return if preview_starting? || preview.running?

    update!(preview_status: :starting)
    PreviewStartJob.perform_later(self)
  end

  # What the preview pane shows: the app, or a screen saying why not. Before the first
  # build there's only the starter app (its sign-up screen), so it stays covered.
  def preview_state
    if setting_up? then "setup"
    elsif working? && !planning? then "building"
    elsif preview_broken? then "broken"
    elsif !built? then "blank"
    elsif preview_starting? then "starting"
    else "live"
    end
  end

  # Whether anything was made yet: the first version is the starter app.
  def built?
    return @built if defined?(@built)
    @built = history.versions(limit: 2).size > 1
  end

  # Picked from the name when the app is first published, then kept: renaming the
  # app doesn't move it away from the address its visitors know.
  def publish_host
    host_for(subdomain || subdomain_for(name))
  end

  def host_for(subdomain)
    "#{subdomain}.#{Rails.configuration.x.publish_domain}"
  end

  # Before the first publish this only picks the address. A published app is moved
  # on ONCE in MoveJob, and the record follows once it's there; links to the old
  # address stop working.
  def change_subdomain(new_subdomain)
    previous = subdomain
    self.subdomain = new_subdomain
    return true unless subdomain_changed?
    return false unless valid?
    return save unless live_deployment

    self.subdomain = previous
    update!(status: :working, activity: "Moving to #{host_for(new_subdomain.strip.downcase)}")
    MoveJob.perform_later(self, new_subdomain.strip.downcase)
    true
  end

  # Not while it works, publishes or moves.
  def movable?
    !busy? && !latest_deployment&.in_progress?
  end

  def publish_url
    "http://#{publish_host}"
  end

  def latest_deployment
    deployments.latest_first.first
  end

  def live_deployment
    deployments.live.latest_first.first
  end

  # Not before anything was built (it would ship the starter app), nor while the app
  # doesn't open: fix it first, then ship it.
  def publishable?
    ready? && built? && !preview_broken? && !latest_deployment&.in_progress?
  end

  def publish
    update!(subdomain: subdomain_for(name)) unless subdomain
    deployments.create!.tap { |deployment| PublishJob.perform_later(deployment) }
  end

  def thumbnail
    Thumbnail.new(self)
  end

  # Anyone with the link can try the preview (see SharesController).
  def share_preview
    update!(share_token: SecureRandom.base58(24)) unless share_token
  end

  # Ends the link and lets out whoever came in through it: a new preview secret outdates
  # every cookie, so the studio reloads its preview to get a fresh one.
  def stop_sharing
    preview_gate.reset
    update!(share_token: nil, preview_version: preview_version + 1)
  end

  # The code of the latest version, zipped in a folder named after the app. Files the
  # agent is still changing aren't in it.
  def archive_to(file)
    shell.run("git", "archive", "--format=zip", "--prefix=#{archive_name}/", "--output=#{file}", "HEAD")
  end

  def archive_name
    subdomain || subdomain_for(name)
  end

  # Commands on the host, in the project's folder: git, publishing.
  def shell
    ProjectShell.new(path)
  end

  # Where the app's own code runs (see Sandbox).
  def sandbox
    Sandbox.for(self)
  end

  def history
    ProjectHistory.new(self)
  end

  def code
    ProjectCode.new(self)
  end

  # The agent leaves a one-line summary of its change here (see config/agent.yml).
  def take_commit_message
    file = path.join("tmp/commit_message.txt")
    return unless file.exist?

    file.read.lines.first.to_s.squish.presence.tap { file.delete }
  end

  def time_zone
    LANGUAGES.dig(language, :time_zone)
  end

  # While setting up or working, the app's files are changing: no renaming, copying or deleting.
  def busy?
    setting_up? || working?
  end

  # The builder's record changes now; the name the app itself shows, in RenameJob.
  def rename(new_name)
    self.name = new_name.to_s.squish
    return true unless name_changed?

    self.status = :working
    save.tap { |saved| RenameJob.perform_later(self) if saved }
  end

  # The name the app shows its visitors lives in its config.
  def write_app_name
    application = path.join("config/application.rb")
    application.write(application.read.sub(/config\.x\.app_name = ".*"/) { %(config.x.app_name = #{name.inspect}) })
  end

  # The name in the app's config, which the agent changes when the owner asks for a new name in the chat.
  def app_name_in_code
    application = path.join("config/application.rb")
    quoted = application.read[/config\.x\.app_name = ("(?:[^"\\]|\\.)*")/, 1] if application.exist?
    quoted&.undump
  rescue RuntimeError # not a plain Ruby string
    nil
  end

  # Takes the name from the app's code after the agent renamed it there. Addresses stay as they are.
  def adopt_app_name_from_code
    code_name = app_name_in_code.to_s.squish
    update!(name: code_name) if code_name.present? && code_name != name
  end

  # A new app with this one's code, version history and preview data, but a fresh chat.
  # The copy belongs to whoever made it.
  def duplicate(owner: self.owner)
    copy_name = "#{name} (copy)"
    Project.create!(name: copy_name, language:, base_sha:, owner:).tap { |copy| DuplicateJob.perform_later(copy, self) }
  end

  # Deletes the preview, code and chat. A published copy keeps running on ONCE.
  # The record goes first: cleaning up takes seconds, and meanwhile an open studio page or a
  # queued job could start the preview again; without the record, nothing finds the app.
  def remove
    destroy!
    preview.stop
    sandbox.remove
    FileUtils.rm_rf(path)
  end

  def accepts_messages?
    ready? || failed?
  end

  # With the interactive agent, the owner can add to a request while it's being worked on.
  def accepts_messages_while_working?
    working? && Rails.configuration.x.agent_backend == "sdk"
  end

  def stop_requested?
    working_since.present? && agent_commands.interrupt.where(created_at: working_since..).exists?
  end

  # The owner's message goes to the agent, in plan or build mode, with the files they
  # attached and the part of the preview they pointed at. While a turn is running
  # (interactive agent only), it joins that turn instead.
  def ask(request, mode:, files: [], pointed: nil)
    return tell_budget_spent if owner&.over_budget?

    message = messages.create!(role: :user, body: request, data: pointed ? { "pointed" => pointed.data } : {})
    attachments = Attachment.save(message, files)
    message.update!(data: message.data.merge("attachments" => attachments.map(&:to_h))) if attachments.any?
    request = [ request.presence, pointed&.to_prompt, attachments_note(attachments) ].compact.join("\n\n")

    if working?
      agent_commands.create!(kind: :message, payload: { "text" => request })
    else
      update!(status: :working)
      AgentTurnJob.perform_later(self, request, mode)
    end
  end

  # Builds straight away by default; plans first only while a plan is being discussed.
  def plans_by_default?
    planning?
  end

  # The agent's latest reply, while the owner hasn't answered it yet.
  def open_reply
    reply = messages.assistant.last
    reply unless reply.nil? || messages.user.where("id > ?", reply.id).exists?
  end

  def latest_proposal
    open_reply if open_reply&.data&.dig("proposal")
  end

  def approval_message
    "Build this plan"
  end

  private
    def attachments_note(attachments)
      return if attachments.empty?

      list = attachments.map { |attachment| "- #{attachment.relative_path} (#{attachment.content_type})" }
      "The owner attached these files. Look at each one (Read shows images and PDFs). " \
        "tmp/ isn't part of the app: copy any file the app should use, such as a logo or photos, into the app.\n#{list.join("\n")}"
    end

    # Gems first: the Gemfile may have changed since they were installed where the app
    # runs, or the app may have moved there (from this machine into a container, say).
    def prepare_preview
      sandbox.run("sh", "-c", "bundle check > /dev/null || bundle install --quiet")
      sandbox.run("bin/rails", "db:prepare")
      sandbox.run("bin/rails", "tailwindcss:build")
      nil
    rescue ProjectShell::Error => error
      error.message
    end

    # The studio address and folder: fixed for the app's life, whatever it's called.
    def assign_slug
      self.slug = SecureRandom.base36(8) while slug.nil? || Project.exists?(slug: slug)
    end

    def subdomain_for(name)
      # Strip Vietnamese diacritics before parameterize, which would drop letters like "ữ".
      base = name.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").tr("đĐ", "dD").parameterize.first(40).delete_suffix("-").presence || "app"
      candidate = base
      candidate = "#{base}-#{SecureRandom.hex(2)}" while Project.where.not(id: id).exists?(subdomain: candidate)
      candidate
    end

    def assign_port
      self.port ||= [ Project.maximum(:port).to_i + 1, Rails.configuration.x.first_preview_port ].max
    end

    def owner_has_room
      errors.add(:base, "You can have #{owner.app_limit} apps. Delete one to make room for another.") if owner&.app_limit_reached?
      errors.add(:base, owner.budget_message) if owner&.over_budget?
    end

    def tell_budget_spent
      messages.create!(role: :notice, body: owner.budget_message)
    end
end
