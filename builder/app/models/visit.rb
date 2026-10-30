# One storefront visitor's day, as far as they got in the shop (STEPS), for the dashboard's
# funnel (ShopReport#funnel). The storefront reports a step only when the visitor gets further
# that day; the visitor is its random cookie id, kept digested. Where they came from is the
# source the storefront saw (Order#source names), the first reported that day.
class Visit < ApplicationRecord
  acts_as_tenant :shop

  STEPS = %w[ visit product cart checkout purchase ].freeze

  # The day's row, moved up to the step (never down).
  def self.reach!(visitor:, step:, source: nil, date: Time.current.in_time_zone(ActsAsTenant.current_tenant.time_zone).to_date)
    number = STEPS.index(step.to_s)&.succ or raise ArgumentError, "No step #{step.inspect}"
    source = source.to_s.downcase
    source = "direct" unless source.match?(/\A[\w.-]{1,40}\z/)
    upsert({ shop_id: ActsAsTenant.current_tenant.id, date:, visitor: Digest::SHA256.hexdigest(visitor.to_s).first(32), source:, step: number },
      unique_by: %i[ shop_id date visitor ],
      on_duplicate: Arel.sql("step = GREATEST(visits.step, EXCLUDED.step), updated_at = EXCLUDED.updated_at"))
  end
end
