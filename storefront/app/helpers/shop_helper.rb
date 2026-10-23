# Pieces of the shop's pages: color swatches, delivery dates, stars, policies' text, the data
# search engines read. The shop itself is current_shop (storefront_kit's StorefrontHelper has
# money, price_range, product_image, theme_setting, shop_menu).
module ShopHelper
  # The cities a star map can be over (public/personalization/cities.json, the Platform's list):
  # [[name, id]] for a select.
  def star_map_cities
    @star_map_cities ||= JSON.parse(Rails.public_path.join("personalization/cities.json").read).map { |city| [ city["name"], city["id"] ] }
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

  # The swatch for a color value ("Forest Green" => "#2f4a35"): the product's own (from Printify),
  # else a known color's, else nil.
  def swatch_color(option, value)
    option.color_for(value) || SWATCHES[value.to_s.downcase.squish]
  end

  # "Arrives Oct 21 – 24" for an order placed today, when the shop says how long delivery takes.
  def delivery_estimate
    first, last = current_shop.shipping&.delivery_dates
    return unless first

    range = if first == last then l(first, format: :delivery)
    elsif first.month == last.month then "#{l(first, format: :delivery)} – #{last.day}"
    else "#{l(first, format: :delivery)} – #{l(last, format: :delivery)}"
    end
    t("products.delivery.arrives", dates: range)
  end

  # "Shipping is $5.00 for the first item and $2.00 for each one after. Free on orders over $50.00."
  def shipping_summary
    shipping = current_shop.shipping
    first, additional, free = shipping.first_item_cents, shipping.additional_item_cents, shipping.free_over_cents
    return t("policies.shipping_summary.free") if first.zero? && additional.zero?

    [ t("policies.shipping_summary.rates", first: money(first), additional: money(additional)),
      (t("policies.shipping_summary.free_from", amount: money(free)) if free) ].compact.join(" ")
  end

  # Five stars, filled up to rating (rounded to the nearest whole star), read out as "Rated 4.6 out of 5".
  def rating_stars(rating, size: 16, **options)
    filled = rating.to_f.round
    tag.span(role: "img", aria: { label: t("products.reviews.rated", rating:) }, **options, class: class_names("inline-flex items-center gap-0.5", options[:class])) do
      safe_join(1.upto(5).map { |star| icon "star", size:, class: star <= filled ? "fill-current text-amber-500" : "fill-current text-line" })
    end
  end

  # schema.org Product data for search engines: one offer per variant, with its price and stock,
  # and its buyers' ratings.
  def product_structured_data(product, reviews)
    rating = product.rating
    data = {
      "@context" => "https://schema.org", "@type" => "Product", "name" => product.title,
      "description" => strip_tags(product.description.to_s).squish.presence,
      "image" => product.images.first(5).map { |image| image.url(:large) },
      "brand" => { "@type" => "Brand", "name" => current_shop.name },
      "offers" => product.variants.map { |variant|
        { "@type" => "Offer", "sku" => variant.catalog_id, "price" => format("%.2f", variant.price_cents / 100.0), "priceCurrency" => current_shop.currency,
          "availability" => "https://schema.org/#{variant.available? ? "InStock" : "OutOfStock"}", "itemCondition" => "https://schema.org/NewCondition",
          "url" => product_url(product, options: variant.options.presence) }
      },
      "aggregateRating" => ({ "@type" => "AggregateRating", "ratingValue" => rating.average, "reviewCount" => rating.count } if rating),
      "review" => (Array(reviews).first(5).map { |review|
        { "@type" => "Review", "reviewRating" => { "@type" => "Rating", "ratingValue" => review.rating }, "author" => { "@type" => "Person", "name" => review.author_name },
          "datePublished" => review.created_at.to_date.iso8601, "reviewBody" => review.body }.compact
      } if rating)
    }.compact
    tag.script(raw(json_escape(data.to_json)), type: "application/ld+json")
  end

  ORDER_STATUS_TONES = {
    "pending" => :yellow, "paid" => :brand, "in_production" => :brand, "shipped" => :green,
    "delivered" => :green, "cancelled" => :gray, "refunded" => :red
  }.freeze

  def order_status_badge(order)
    badge t(order.status, scope: "orders.statuses"), tone: ORDER_STATUS_TONES.fetch(order.status, :gray)
  end

  # A moment in the buyer's own time zone (the local-time controller), which only their browser
  # knows; the date alone until it runs, so a time in the wrong zone never shows.
  def local_time(time, date_only: false)
    tag.time l(time.to_date, format: :long), datetime: time.iso8601,
      data: { controller: "local-time", local_time_date_only_value: date_only }
  end

  # The variants of a product for the variant picker: what each costs and whether it can be bought.
  def variants_json(product)
    product.variants.map do |variant|
      image = product.image_for(variant)
      { id: variant.id, options: variant.options, available: variant.available?, sold_out: !variant.available? && variant.stock == 0,
        image: image&.url(:large), price: money(variant.price_cents), compare_at_price: (money(variant.compare_at_price_cents) if variant.on_sale?),
        saving: (t("products.show.save", percent: variant.sale_percent) if variant.on_sale?) }
    end.to_json
  end

  # Policy text (and size guides) as written in the admin: paragraphs split by blank lines, "## "
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

  # A link the owner put in a menu: a path on this storefront or a full address.
  def shop_menu_link(item, **options)
    url = item["url"].to_s
    external = url.start_with?("http")
    link_to item["label"], url, **options, **(external ? { target: "_blank", rel: "noopener" } : {})
  end
end
