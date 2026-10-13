# What buyers do on the site, for the owner's ad accounts (Meta, TikTok, Google; their IDs are in
# /admin/settings): a product viewed, added to the cart, a checkout started, an order placed.
# Controllers call track; app/javascript/tracking.js sends each event once to every connected
# account. An event before a redirect waits in the flash for the next page.
module Tracking
  extend ActiveSupport::Concern

  included do
    helper_method :tracking_events
  end

  private
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
