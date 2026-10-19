# What a storefront's agent needed from the Platform and the shop's data didn't have: a field, an
# endpoint, a setting. The agent files it with bin/request in the storefront (it builds only the
# look, on the API's fields), the builder takes it in after the turn (Project#take_platform_requests),
# and it shows in the shop's admin and to the builder's administrators. The same request again
# counts up instead of making another.
class PlatformRequest < ApplicationRecord
  STATUSES = %w[ open done declined ].freeze

  acts_as_tenant :shop
  belongs_to :project, optional: true

  validates :body, presence: true, length: { maximum: 2000 }
  validates :status, inclusion: { in: STATUSES }

  normalizes :body, with: ->(body) { body.to_s.strip.gsub(/\r\n?/, "\n") }

  scope :open, -> { where(status: "open") }
  scope :newest_first, -> { order(updated_at: :desc, id: :desc) }

  def self.file(body, project:)
    body = body.to_s.strip.first(2000)
    return if body.blank?

    request = open.find_by(body:)
    request ? request.tap { request.update!(times_asked: request.times_asked + 1) } : create!(body:, project:)
  end
end
