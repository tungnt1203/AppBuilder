class Project < ApplicationRecord
  LANGUAGES = { "vi" => { name: "Tiếng Việt", time_zone: "Asia/Ho_Chi_Minh" }, "en" => { name: "English", time_zone: "UTC" } }

  has_many :messages, -> { order(:id) }, dependent: :destroy

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

  def shell
    ProjectShell.new(path)
  end

  def time_zone
    LANGUAGES.dig(language, :time_zone)
  end

  def accepts_messages?
    ready? || failed?
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
