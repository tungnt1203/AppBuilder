class Project < ApplicationRecord
  LANGUAGES = { "vi" => { name: "Tiếng Việt", time_zone: "Asia/Ho_Chi_Minh" }, "en" => { name: "English", time_zone: "UTC" } }

  has_many :messages, -> { order(:id) }, dependent: :destroy
  has_many :deployments, dependent: :destroy

  enum :status, %w[ setting_up ready working failed ].index_by(&:itself), default: "setting_up"

  validates :name, presence: true
  validates :language, inclusion: { in: LANGUAGES.keys }

  before_validation :assign_slug, :assign_port, on: :create

  broadcasts_refreshes

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

  def publishable?
    ready? && !latest_deployment&.in_progress?
  end

  def publish
    deployments.create!.tap { |deployment| PublishJob.perform_later(deployment) }
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

  def accepts_messages?
    ready? || failed?
  end

  # The owner's message goes to the agent, in plan or build mode.
  def ask(request, mode:)
    messages.create!(role: :user, body: request)
    update!(status: :working)
    AgentTurnJob.perform_later(self, request, mode)
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
