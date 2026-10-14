# What buyers do on the site, for the owner's ad accounts (Meta, TikTok, Google; their IDs are in
# /admin/settings): a product viewed, added to the cart, a checkout started, an order placed.
# Controllers call track; app/javascript/tracking.js sends each event once to every connected
# account. An event before a redirect waits in the flash for the next page. Purchases also go to
# Meta from the server (Meta::Purchase), with the browser's details from tracking_attribution.
module Tracking
  extend ActiveSupport::Concern

  included do
    helper_method :tracking_events
    before_action :remember_meta_click, if: -> { params[:fbclid].present? }
  end

  private
    # A visit from a Meta ad (?fbclid=…) keeps the click in Meta's _fbc cookie, as the pixel does,
    # so the purchase sent from the server is tied to the ad even when the pixel is blocked.
    def remember_meta_click
      fbclid = params[:fbclid].to_s
      return unless Store.current.meta_pixel_id && fbclid.match?(/\A[\w-]{1,500}\z/)
      return if cookies[:_fbc].to_s.end_with?(".#{fbclid}")

      cookies[:_fbc] = { value: "fb.1.#{(Time.current.to_f * 1000).to_i}.#{fbclid}", expires: 90.days, same_site: :lax }
    end

    # The buyer's browser, kept on the order at checkout for Meta to match the purchase to an ad.
    def tracking_attribution
      return {} unless Store.current.meta_pixel_id

      { "fbp" => cookies[:_fbp], "fbc" => cookies[:_fbc], "ip" => request.remote_ip,
        "user_agent" => request.user_agent.to_s.first(500), "url" => request.referer.to_s.first(500) }.compact_blank
    end

    # track :add_to_cart, items: [ tracked_variant(variant, 2) ], redirect: true
    def track(name, items:, value_cents: nil, order: nil, redirect: false)
      return unless Store.current.ad_tracking?

      value_cents ||= items.sum { |item| (item["price"] * 100).round * item["quantity"] }
      event = { "name" => name.to_s, "id" => "#{name}-#{order&.number || SecureRandom.hex(6)}", "order" => order&.number,
        "currency" => order&.currency || Store.current.currency, "value" => (value_cents / 100.0).round(2), "items" => items }
      redirect ? (flash[:tracking] = Array(flash[:tracking]) + [ event ]) : (@tracking_events ||= []) << event
    end

    def tracking_events
      Array(flash[:tracking]) + Array(@tracking_events)
    end

    def tracked_variant(variant, quantity = 1)
      tracked_item(variant.catalog_id, [ variant.product.title, variant.title ].compact.join(" – "), variant.price_cents, quantity)
    end

    def tracked_line(line_item)
      tracked_item(line_item.variant&.catalog_id || line_item.sku.presence || "variant-#{line_item.variant_id}", [ line_item.product_title, line_item.variant_title ].compact.join(" – "),
        line_item.unit_price_cents, line_item.quantity)
    end

    def tracked_item(id, name, price_cents, quantity)
      { "id" => id, "name" => name, "price" => (price_cents / 100.0).round(2), "quantity" => quantity }
    end
end
