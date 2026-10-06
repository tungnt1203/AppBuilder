class Project < ApplicationRecord
  LANGUAGES = { "vi" => { name: "Tiếng Việt", time_zone: "Asia/Ho_Chi_Minh" }, "en" => { name: "English", time_zone: "UTC" } }

  has_many :messages, -> { order(:id) }, dependent: :destroy
  has_many :deployments, dependent: :destroy
  has_many :agent_commands, dependent: :delete_all

  enum :status, %w[ setting_up ready working failed ].index_by(&:itself), default: "setting_up"
  enum :preview_status, %w[ starting running broken ].index_by(&:itself), prefix: :preview

  validates :name, presence: true
  validates :language, inclusion: { in: LANGUAGES.keys }

  before_validation :assign_slug, :assign_port, on: :create

  broadcasts_refreshes
  after_update_commit -> { broadcast_refresh_later_to(:projects) }, if: -> { saved_change_to_status? || saved_change_to_preview_status? }
  after_destroy_commit -> { thumbnail.delete; broadcast_refresh_later_to(:projects) }

  scope :ordered, -> { order(updated_at: :desc) }

  def to_param
    slug
  end

  def path
    Rails.configuration.x.projects_root.join(slug)
  end

  def preview_url
    "http://localhost:#{port}"
  end

  def preview
    PreviewServer.new(self)
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

  # What the preview pane shows: the app, or a screen saying why not.
  def preview_state
    if setting_up? then "setup"
    elsif working? && !planning? then "building"
    elsif preview_starting? then "starting"
    elsif preview_broken? then "broken"
    else "live"
    end
  end

  def publish_host
    "#{slug}.#{Rails.configuration.x.publish_domain}"
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

  # Not while the app doesn't open: fix it first, then ship it.
  def publishable?
    ready? && !preview_broken? && !latest_deployment&.in_progress?
  end

  def publish
    deployments.create!.tap { |deployment| PublishJob.perform_later(deployment) }
  end

  def thumbnail
    Thumbnail.new(self)
  end

  def shell
    ProjectShell.new(path)
  end

  def history
    ProjectHistory.new(self)
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

  # A new app with this one's code, version history and preview data, but a fresh chat.
  def duplicate
    copy_name = language == "vi" ? "#{name} (bản sao)" : "#{name} (copy)"
    Project.create!(name: copy_name, language:, base_sha:).tap { |copy| DuplicateJob.perform_later(copy, self) }
  end

  # Deletes the preview, code and chat. A published copy keeps running on ONCE.
  def remove
    preview.stop
    destroy!
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

  # The owner's message goes to the agent, in plan or build mode. While a turn is
  # running (interactive agent only), it joins that turn instead.
  def ask(request, mode:)
    messages.create!(role: :user, body: request)

    if working?
      agent_commands.create!(kind: :message, payload: { "text" => request })
    else
      update!(status: :working)
      AgentTurnJob.perform_later(self, request, mode)
    end
  end

  def answer(ask_id, answers)
    messages.create!(role: :user, body: answers.map { |question, answer| "#{question} #{answer}" }.join("\n"))
    agent_commands.create!(kind: :answer, payload: { "id" => ask_id, "answers" => answers })
  end

  # Plan first for a new app, or while a plan is being discussed.
  def plans_by_default?
    planning? || history.versions.size <= 1
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
    language == "vi" ? "Làm theo kế hoạch này" : "Build this plan"
  end

  private
    def prepare_preview
      shell.run("bin/rails", "db:prepare")
      shell.run("bin/rails", "tailwindcss:build")
      nil
    rescue ProjectShell::Error => error
      error.message
    end

    def assign_slug
      # Strip Vietnamese diacritics before parameterize, which would drop letters like "ữ".
      base = name.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").tr("đĐ", "dD").parameterize.presence || "app"
      self.slug = base
      self.slug = "#{base}-#{SecureRandom.hex(2)}" while Project.exists?(slug: slug)
    end

    def assign_port
      self.port ||= [ Project.maximum(:port).to_i + 1, Rails.configuration.x.first_preview_port ].max
    end
end
