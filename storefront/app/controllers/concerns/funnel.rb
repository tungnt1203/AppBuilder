# How far each visitor gets in the shop today, for the owner's funnel in the admin: a page, a
# product, the cart, checkout, an order. Each browser has a random id in a cookie (nothing that
# names anyone), and a step goes to the Platform only when the visitor gets further that day, so
# five calls a day at most. Crawlers aren't counted.
module Funnel
  extend ActiveSupport::Concern

  STEPS = %w[ visit product cart checkout purchase ].freeze
  # Tracking's events, as the step each one reaches.
  EVENT_STEPS = { view_content: "product", add_to_cart: "cart", initiate_checkout: "checkout", purchase: "purchase" }.freeze
  CRAWLERS = /bot|crawl|spider|slurp|facebookexternalhit|preview|lighthouse|headless/i

  included do
    before_action -> { reach "visit" }, if: -> { request.get? && request.format.html? }
  end

  private
    def reach(step)
      return if request.user_agent.to_s.match?(CRAWLERS)

      today = Date.current.iso8601
      day, furthest = cookies[:_fs].to_s.split(":")
      furthest = day == today ? furthest.to_i : 0
      number = STEPS.index(step) + 1
      return if number <= furthest

      cookies[:_fs] = { value: "#{today}:#{number}", expires: 1.day, same_site: :lax }
      storefront.record_visit(visitor: visitor_id, step:, source: cookies[:_src])
    end

    def visitor_id
      cookies[:_vid] = { value: SecureRandom.hex(16), expires: 1.year, same_site: :lax } unless cookies[:_vid].to_s.match?(/\A\h{32}\z/)
      cookies[:_vid]
    end
end
