# An event Stripe or Printify sent a shop (Webhooks::StripeController, Webhooks::PrintifyController),
# kept once per shop and event id. Handling it records what came of it: `processed` with the
# order it changed, `ignored` when it isn't about one of the shop's orders (another shop on the
# same Stripe or Printify account), `failed` with the error, which a delivery sent again retries.
class WebhookEvent < ApplicationRecord
  PROVIDERS = %w[ stripe printify ].freeze
  STATUSES = %w[ received processed ignored failed ].freeze

  acts_as_tenant :shop
  belongs_to :order, optional: true

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :event_id, :kind, presence: true

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # Handles the event once, even when two deliveries of it arrive together: yields unless the
  # shop already handled it, and the block returns the order it changed (nil when it's about
  # none of the shop's orders). An error is recorded and raised again, so the provider sends the
  # event again later.
  def self.handle(provider:, event_id:, kind:, payload:)
    event = create_or_find_by!(provider:, event_id: event_id.to_s) { |new_event| new_event.assign_attributes(kind:, payload:) }
    event.with_lock do
      next unless event.status.in?(%w[ received failed ])

      order = yield
      event.update!(status: order ? "processed" : "ignored", order:, error: nil)
    end
    event
  rescue StandardError => error
    event.update_columns(status: "failed", error: "#{error.class}: #{error.message}".first(2000), updated_at: Time.current) if event&.persisted?
    raise
  end
end
