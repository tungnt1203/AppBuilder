# What buyers do on the site, for the owner's ad accounts (Meta, TikTok, Google; their IDs are in
# the shop's settings): a product viewed, added to the cart, a checkout started, an order placed.
# Controllers call track; app/javascript/tracking.js sends each event once to every connected
# account. An event before a redirect waits in the flash for the next page. Purchases also go to
# Meta from the Platform (its Conversions API), with the browser's details from tracking_attribution.
module Tracking
  extend ActiveSupport::Concern

  included do
    helper_method :tracking_events
    before_action :remember_meta_click, if: -> { params[:fbclid].present? }
    before_action :remember_source, if: -> { params.values_at(*SOURCE_CLICKS.keys, :utm_source).any?(&:present?) }
  end

  # An ad network's click id in the address, for where the buyer came from.
  SOURCE_CLICKS = { fbclid: "facebook", ttclid: "tiktok", gclid: "google" }.freeze

  private
    # A visit from a Meta ad (?fbclid=…) keeps the click in Meta's _fbc cookie, as the pixel does,
    # so the purchase sent from the Platform is tied to the ad even when the pixel is blocked.
    def remember_meta_click
      fbclid = params[:fbclid].to_s
      return unless current_shop.pixels&.meta && fbclid.match?(/\A[\w-]{1,500}\z/)
      return if cookies[:_fbc].to_s.end_with?(".#{fbclid}")

      cookies[:_fbc] = { value: "fb.1.#{(Time.current.to_f * 1000).to_i}.#{fbclid}", expires: 90.days, same_site: :lax }
    end

    # Where the visit came from (the last ad or link with utm_source), for the owner's sales by
    # source in the admin: kept 30 days, as ad networks count a click.
    def remember_source
      source = SOURCE_CLICKS.find { |key, _| params[key].present? }&.last || params[:utm_source].to_s.downcase.first(40)
      cookies[:_src] = { value: source, expires: 30.days, same_site: :lax } if source.match?(/\A[\w.-]+\z/)
    end

    # Kept on the order at checkout: where the buyer came from, and their browser for Meta to match
    # the purchase to an ad.
    def tracking_attribution
      source = { source: cookies[:_src] }.compact_blank
      return source unless current_shop.pixels&.meta

      { fbp: cookies[:_fbp], fbc: cookies[:_fbc], ip: request.remote_ip,
        user_agent: request.user_agent.to_s.first(500), url: request.referer.to_s.first(500), **source }.compact_blank
    end

    # track :add_to_cart, items: [ tracked_variant(product, variant, 2) ], redirect: true
    # Each event is also a step of the shop's funnel (Funnel), pixels or not.
    def track(name, items:, value_cents: nil, order: nil, redirect: false)
      reach Funnel::EVENT_STEPS[name] if Funnel::EVENT_STEPS.key?(name)
      return unless current_shop.ad_tracking?

      value_cents ||= items.sum { |item| (item["price"] * 100).round * item["quantity"] }
      event = { "name" => name.to_s, "id" => "#{name}-#{order&.number || SecureRandom.hex(6)}", "order" => order&.number,
        "currency" => order&.currency || current_shop.currency, "value" => (value_cents / 100.0).round(2), "items" => items }
      redirect ? (flash[:tracking] = Array(flash[:tracking]) + [ event ]) : (@tracking_events ||= []) << event
    end

    def tracking_events
      Array(flash[:tracking]) + Array(@tracking_events)
    end

    def tracked_variant(product, variant, quantity = 1)
      tracked_item(variant.catalog_id, [ product.title, variant.title ].compact.join(" – "), variant.price_cents, quantity)
    end

    def tracked_cart_item(item)
      tracked_variant(item.product, item.variant, item.quantity)
    end

    def tracked_order_item(item)
      tracked_item(item["catalog_id"] || item.product_slug, [ item.title, item.variant_title ].compact.join(" – "), item.unit_price_cents, item.quantity)
    end

    def tracked_item(id, name, price_cents, quantity)
      { "id" => id, "name" => name, "price" => (price_cents / 100.0).round(2), "quantity" => quantity }
    end
end
