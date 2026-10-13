# Pieces of the shop shared by the site and /admin.
module StoreHelper
  # A product's photo in one of its sizes (:thumb, :card, :large), or a placeholder when it has none.
  def product_image(product, size: :card, image: product.cover_image, **options)
    options[:class] = class_names("bg-surface-muted object-cover", options[:class])
    if image&.representable?
      image_tag image.variant(size), alt: options.delete(:alt) || product.title, loading: "lazy", **options
    else
      tag.div(icon("shirt", size: 32, stroke: 1.5), class: class_names(options[:class], "grid place-items-center text-muted"), role: "img", aria: { label: product.title })
    end
  end

  # Colors print-on-demand blanks come in, for swatches on the product page. Values the shop
  # writes otherwise ("Vintage wash") stay text.
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

  # The swatch for a color value ("Forest Green" => "#2f4a35"), or nil when it isn't a known color.
  def swatch_color(value)
    SWATCHES[value.to_s.downcase.squish]
  end

  # "Arrives Oct 21 – 24" for an order placed today, when the shop says how long delivery takes.
  def delivery_estimate(store = Store.current)
    first, last = store.delivery_dates
    return unless first

    range = if first == last then l(first, format: :delivery)
    elsif first.month == last.month then "#{l(first, format: :delivery)} – #{last.day}"
    else "#{l(first, format: :delivery)} – #{l(last, format: :delivery)}"
    end
    t("products.delivery.arrives", dates: range)
  end

  # schema.org Product data for search engines: one offer per variant, with its price and stock.
  def product_structured_data(product)
    currency = Store.current.currency
    data = {
      "@context" => "https://schema.org", "@type" => "Product", "name" => product.title,
      "description" => strip_tags(product.description.to_s).squish.presence,
      "image" => product.images.select(&:representable?).first(5).map { |image| url_for(image.variant(:large)) },
      "brand" => { "@type" => "Brand", "name" => Rails.configuration.x.app_name },
      "offers" => product.variants.map { |variant|
        { "@type" => "Offer", "sku" => variant.catalog_id, "price" => format("%.2f", variant.price_cents / 100.0), "priceCurrency" => currency,
          "availability" => "https://schema.org/#{variant.buyable? ? "InStock" : "OutOfStock"}", "itemCondition" => "https://schema.org/NewCondition",
          "url" => product_url(product, options: variant.option_values.presence) }
      }
    }.compact
    tag.script(raw(json_escape(data.to_json)), type: "application/ld+json")
  end

  # "24.00 USD", how product feeds write a price.
  def feed_price(cents, currency)
    format = Store::CURRENCIES.fetch(currency)
    "#{number_with_precision(BigDecimal(cents) / 100, precision: format[:precision])} #{currency}"
  end

  # How much a variant on sale saves, as a whole percentage: 20.
  def sale_percent(variant)
    return unless variant&.on_sale?

    ((variant.compare_at_price_cents - variant.price_cents) * 100.0 / variant.compare_at_price_cents).round
  end

  ORDER_STATUS_TONES = {
    "pending" => :yellow, "paid" => :brand, "in_production" => :brand, "shipped" => :green,
    "delivered" => :green, "cancelled" => :gray, "refunded" => :red
  }.freeze

  def order_status_badge(order)
    badge t(order.status, scope: "orders.statuses"), tone: ORDER_STATUS_TONES.fetch(order.status, :gray)
  end

  PRODUCT_STATUS_TONES = { "active" => :green, "draft" => :yellow, "archived" => :gray }.freeze

  def product_status_badge(product)
    badge t(product.status, scope: "products.statuses"), tone: PRODUCT_STATUS_TONES.fetch(product.status, :gray)
  end

  # The variants of a product for the variant picker: what each costs and whether it can be bought.
  def variants_json(product)
    product.variants.map do |variant|
      image = product.image_for(variant)
      { id: variant.id, options: variant.option_values, available: variant.buyable?,
        image: (url_for(image.variant(:large)) if image&.representable?),
        price: money(variant.price_cents), compare_at_price: (money(variant.compare_at_price_cents) if variant.on_sale?),
        saving: (t("products.show.save", percent: sale_percent(variant)) if variant.on_sale?) }
    end.to_json
  end

  # A policy's starting text for this shop (app/views/admin/policies/templates), for the owner to
  # read and adjust before saving.
  def policy_template(id, store)
    render(partial: "admin/policies/templates/#{id}", formats: :text, locals: {
      shop: Rails.configuration.x.app_name, currency: store.currency,
      contact: store.contact_email.presence || "[your email]", shipping: shipping_summary(store)
    }).strip
  end

  def shipping_summary(store)
    first, additional, free = store.shipping_first_item_cents, store.shipping_additional_item_cents, store.free_shipping_threshold_cents
    return t("policies.shipping_summary.free") if first.zero? && additional.zero?

    [ t("policies.shipping_summary.rates", first: money(first, store.currency), additional: money(additional, store.currency)),
      (t("policies.shipping_summary.free_from", amount: money(free, store.currency)) if free) ].compact.join(" ")
  end

  # Policy text (and size guides) as written in /admin: paragraphs split by blank lines, "## "
  # starts a heading, lines starting with "- " make a list, and lines with "|" between cells make
  # a table whose first line is the header ("Size | Chest | Length").
  def policy_text(text)
    blocks = text.to_s.strip.split(/\r?\n\s*\r?\n/).map do |block|
      lines = block.lines.map(&:strip)
      if lines.many? && lines.all? { |line| line.include?("|") }
        text_table(lines.map { |line| line.delete_prefix("|").delete_suffix("|").split("|").map(&:strip) })
      elsif lines.one? && lines.first.start_with?("## ")
        tag.h2(lines.first.delete_prefix("## "), class: "mt-10 font-display text-xl font-semibold text-ink")
      elsif lines.all? { |line| line.start_with?("- ") }
        tag.ul(safe_join(lines.map { |line| tag.li(line.delete_prefix("- ")) }), class: "mt-4 list-disc space-y-1 pl-5")
      else
        tag.p(safe_join(lines, tag.br), class: "mt-4")
      end
    end
    safe_join(blocks)
  end

  def text_table(rows)
    header, *body = rows.reject { |cells| cells.all? { |cell| cell.match?(/\A:?-+:?\z/) } }
    tag.div(class: "mt-4 overflow-x-auto") do
      tag.table(class: "w-full text-left text-sm tabular-nums") do
        tag.thead(tag.tr(safe_join(header.map { |cell| tag.th(cell, class: "border-b border-line py-2 pr-4 font-medium") }))) +
          tag.tbody(safe_join(body.map { |cells| tag.tr(safe_join(cells.map { |cell| tag.td(cell, class: "border-b border-line py-2 pr-4") })) }))
      end
    end
  end

  # "10% off · from $30 · until Oct 31" for the discounts list.
  def discount_summary(discount)
    [ case discount.kind
      when "percentage" then t("admin.discounts.summary.percentage", percent: discount.percent_off)
      when "fixed_amount" then t("admin.discounts.summary.fixed_amount", amount: money(discount.amount_off_cents))
      else t("admin.discounts.summary.free_shipping")
      end,
      (t("admin.discounts.summary.minimum", amount: money(discount.minimum_subtotal_cents)) if discount.minimum_subtotal_cents),
      (t("admin.discounts.summary.until", date: l(discount.ends_at, format: :short)) if discount.ends_at),
      (t("admin.discounts.summary.limit", count: discount.usage_limit) if discount.usage_limit) ].compact.join(" · ")
  end
end
