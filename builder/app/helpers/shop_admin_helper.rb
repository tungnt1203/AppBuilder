# Pieces of a shop's admin (ShopAdmin::*) about its catalog and orders.
module ShopAdminHelper
  # An address on the shop's storefront: storefront_url("/products/#{product.slug}").
  def storefront_url(path = "/")
    current_shop.storefront_url(path)
  end

  # A product's photo in one of its sizes (:thumb, :card, :large), or a placeholder when it has none.
  def product_image(product, size: :card, image: product.cover_image, **options)
    options[:class] = class_names("bg-surface-muted object-cover", options[:class])
    if image&.representable?
      image_tag image.variant(size), alt: options.delete(:alt) || product.title, loading: "lazy", **options
    else
      tag.div(icon("shirt", size: 32, stroke: 1.5), class: class_names(options[:class], "grid place-items-center text-muted"), role: "img", aria: { label: product.title })
    end
  end

  # Colors print-on-demand blanks come in, for the swatches next to a product's photos. Values
  # the shop writes otherwise ("Vintage wash") stay text.
  SWATCHES = {
    "black" => "#111111", "white" => "#ffffff", "navy" => "#1f2a44", "grey" => "#9ca3af", "gray" => "#9ca3af",
    "heather grey" => "#b8b8b8", "heather gray" => "#b8b8b8", "charcoal" => "#36393f", "dark grey" => "#4b4f56",
    "red" => "#c8102e", "maroon" => "#5c1a24", "burgundy" => "#6d1f2c", "pink" => "#f4b6c2", "light pink" => "#f9d5dc",
    "orange" => "#f26b1d", "yellow" => "#f6d04d", "gold" => "#d4a72c", "mustard" => "#d8a31a",
    "green" => "#2e7d32", "forest" => "#2f4a35", "forest green" => "#2f4a35", "olive" => "#6b6b3a", "military green" => "#5a5f3c",
    "mint" => "#bfe6d0", "blue" => "#2563eb", "royal" => "#2346a8", "royal blue" => "#2346a8", "light blue" => "#a9c8e8",
    "sky" => "#8ec5ea", "teal" => "#1f7a7a", "purple" => "#6b3fa0", "lavender" => "#c9b6e4",
    "brown" => "#5b3a29", "chocolate" => "#4a2c20", "sand" => "#d8c7a6", "tan" => "#c9a97e", "natural" => "#efe6d2",
    "cream" => "#f3ecd8", "ivory" => "#f6f1e3", "beige" => "#e3d5b8", "khaki" => "#bfae84", "stone" => "#c8c2b4"
  }.freeze

  def color_option?(name)
    name.to_s.match?(/\bcolou?r\b/i)
  end

  # The swatch for a color value ("Forest Green" => "#2f4a35"): the product's own (from Printify),
  # else a known color's, else nil.
  def swatch_color(value, product = nil)
    product&.option_colors&.dig(value.to_s) || SWATCHES[value.to_s.downcase.squish]
  end

  # Five stars, filled up to rating (rounded to the nearest whole star), read out as "Rated 4.6 out of 5".
  def rating_stars(rating, size: 16, **options)
    filled = rating.to_f.round
    tag.span(role: "img", aria: { label: t("shop_admin.product_reviews.rated", rating: rating) }, **options, class: class_names("inline-flex items-center gap-0.5", options[:class])) do
      safe_join(1.upto(5).map { |star| icon "star", size:, class: star <= filled ? "fill-current text-amber-500" : "fill-current text-line" })
    end
  end

  ORDER_STATUS_TONES = {
    "pending" => :yellow, "paid" => :brand, "in_production" => :brand, "shipped" => :green,
    "delivered" => :green, "cancelled" => :gray, "refunded" => :red
  }.freeze

  # The address field Printify turned an order down for, from its error ("address_to.region:
  # …"), to open the address editor at it; nil when it wasn't the address.
  def printify_rejected_field(order)
    error = order.fulfillment_error.to_s.downcase
    return if error.empty? || order.printify_order_id.present?

    { /phone/ => :phone, /region|state|province/ => :shipping_region, /zip|postal/ => :shipping_postal_code,
      /city/ => :shipping_city, /country/ => :shipping_country, /address/ => :shipping_address1 }.find { |pattern, _| error.match?(pattern) }&.last
  end

  def order_status_badge(order)
    badge t(order.status, scope: "orders.statuses"), tone: ORDER_STATUS_TONES.fetch(order.status, :gray)
  end

  PRODUCT_STATUS_TONES = { "active" => :green, "draft" => :yellow, "archived" => :gray }.freeze

  def product_status_badge(product)
    badge t(product.status, scope: "products.statuses"), tone: PRODUCT_STATUS_TONES.fetch(product.status, :gray)
  end

  # How much of the price the shop keeps over the cost, in percent ("54"); nil without both.
  def margin_percent(price_cents, cost_cents)
    ((price_cents - cost_cents) * 100.0 / price_cents).round if price_cents.to_i.positive? && cost_cents
  end

  # A policy's starting text for this shop (shop_admin/policies/templates), for the owner to read
  # and adjust before saving.
  def policy_template(id, store)
    render(partial: "shop_admin/policies/templates/#{id}", formats: :text, locals: {
      shop: current_shop.name, currency: store.currency,
      contact: store.contact_email.presence || "[your email]", shipping: shipping_summary(store)
    }).strip
  end

  def shipping_summary(store)
    first, additional, free = store.shipping_first_item_cents, store.shipping_additional_item_cents, store.free_shipping_threshold_cents
    return t("policies.shipping_summary.free") if first.zero? && additional.zero?

    [ t("policies.shipping_summary.rates", first: money(first, store.currency), additional: money(additional, store.currency)),
      (t("policies.shipping_summary.free_from", amount: money(free, store.currency)) if free) ].compact.join(" ")
  end

  # "10% off · from $30 · until Oct 31" for the discounts list.
  def discount_summary(discount)
    [ case discount.kind
      when "percentage" then t("shop_admin.discounts.summary.percentage", percent: discount.percent_off)
      when "fixed_amount" then t("shop_admin.discounts.summary.fixed_amount", amount: money(discount.amount_off_cents))
      else t("shop_admin.discounts.summary.free_shipping")
      end,
      (t("shop_admin.discounts.summary.minimum", amount: money(discount.minimum_subtotal_cents)) if discount.minimum_subtotal_cents),
      (t("shop_admin.discounts.summary.until", date: l(discount.ends_at, format: :short)) if discount.ends_at),
      (t("shop_admin.discounts.summary.limit", count: discount.usage_limit) if discount.usage_limit) ].compact.join(" · ")
  end
end
