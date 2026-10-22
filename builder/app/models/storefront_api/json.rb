# The shapes the Storefront API answers with (docs/storefront-api.md): plain hashes, money in
# cents with the shop's currency, photos as absolute URLs in three sizes. One place for them, so
# every endpoint shows a product, a cart or an order the same way.
class StorefrontApi::Json
  IMAGE_SIZES = %i[ thumb card large ].freeze

  def initialize(store:, url_options:)
    @store, @url_options = store, url_options
  end

  def shop(shop, preview:)
    {
      name: shop.name, currency: shop.currency, preview:,
      announcement: @store.announcement,
      shipping: { first_item_cents: @store.shipping_first_item_cents, additional_item_cents: @store.shipping_additional_item_cents,
        free_over_cents: @store.free_shipping_threshold_cents, ships_to: @store.ship_to_countries.presence,
        delivery_days: ({ min: @store.delivery_days_min, max: @store.delivery_days_max || @store.delivery_days_min } if @store.delivery_days_min),
        delivery_dates: @store.delivery_dates&.then { |first, last| { first: first.iso8601, last: last.iso8601 } },
        countries: @store.countries_for_checkout.map { |name, code| { code:, name:, regions: Region.for(code) } } },
      payment_methods: @store.payment_methods,
      tax_at_payment: @store.stripe_tax? && @store.payment_methods.include?("stripe"),
      payment_instructions: @store.payment_instructions.presence,
      pixels: { meta: @store.meta_pixel_id, tiktok: @store.tiktok_pixel_id, google: @store.google_tag_id },
      policies: @store.published_policies.map { |id| { id:, title: I18n.t("policies.titles.#{id}") } },
      contact: { email: @store.contact_email.presence, phone: @store.contact_phone.presence, address: @store.business_address.presence },
      theme_settings: theme_settings
    }
  end

  def product_summary(product)
    low, high = product.price_range
    sale = product.variants.select(&:on_sale?)
    {
      slug: product.slug, title: product.title, available: product.available?,
      price: { min_cents: low, max_cents: high, currency: @store.currency,
        compare_at_cents: sale.map(&:compare_at_price_cents).max },
      image: image(product.cover_image, alt: product.title),
      second_image: image(product.images.select(&:representable?).second, alt: product.title),
      rating: product.rating_summary
    }
  end

  def product(product)
    product_summary(product).merge(
      description: product.description.presence,
      size_guide: product.size_guide.presence,
      size_option: product.size_option_name,
      made_to_order: product.printify_product_id.present?,
      options: product.options.map { |_slot, name, values|
        { name:, values:, colors: (values.index_with { |value| product.option_colors[value] }.compact.presence if name.match?(/\bcolou?r\b/i)) }.compact
      },
      variants: product.variants.map { |variant| variant(variant, product) },
      images: product.images.select(&:representable?).map { |photo| image(photo, alt: product.title).merge(option_value: product.photo_option(photo)) },
      collections: product.collections.map { |collection| { slug: collection.slug, title: collection.title } },
      custom_fields: product.custom_field_entries,
      buyer_inputs: buyer_inputs(product)
    )
  end

  def variant(variant, product = variant.product)
    {
      id: variant.id, title: variant.title, options: variant.option_values, sku: variant.sku, catalog_id: variant.catalog_id,
      price_cents: variant.price_cents, compare_at_price_cents: (variant.compare_at_price_cents if variant.on_sale?),
      available: variant.buyable?,
      stock: (variant.inventory_quantity if variant.track_inventory? && variant.low_stock?),
      image_id: product.image_for(variant)&.id
    }
  end

  # The cart as the buyer sees it: only what can still be bought, the discount it gets now, and
  # how far it is from free shipping.
  def cart(cart)
    items = cart.buyable_items
    subtotal = items.sum(&:total_cents)
    discount = cart.discount
    {
      token: cart.token, currency: @store.currency,
      items: items.map { |item| cart_item(item) },
      item_count: items.sum(&:quantity), subtotal_cents: subtotal,
      discount: ({ code: discount.code, kind: discount.kind, amount_cents: discount.amount_for(subtotal) } if discount),
      free_shipping_remaining_cents: (@store.free_shipping_remaining_cents(subtotal) if items.any?)
    }
  end

  def cart_item(item)
    product = item.product
    { id: item.id, quantity: item.quantity, line_total_cents: item.total_cents,
      product: { slug: product.slug, title: product.title, image: image(product.image_for(item.variant), alt: product.title) },
      variant: variant(item.variant, product) }.tap { |line| add_properties(line, item, product.image_for(item.variant)) }
  end

  # What a checkout comes to before it's placed: shipping is only known once the address is
  # complete enough to quote (shipping_known), until then it's the shop's flat rate.
  def checkout(checkout)
    {
      currency: @store.currency, items: checkout.items.map { |item| cart_item(item) },
      subtotal_cents: checkout.subtotal_cents, discount_cents: checkout.discount_cents, discount_code: checkout.discount&.code,
      shipping_cents: checkout.shipping_cents, shipping_known: checkout.shipping_known?, total_cents: checkout.total_cents,
      payment_methods: checkout.payment_methods, phone_required: checkout.phone_required?
    }
  end

  # The buyer's order: what they bought, what it came to, where it goes, how far along it is.
  def order(order)
    {
      token: order.token, number: order.number, name: order.name, status: order.status, test: order.test?,
      placed_at: order.created_at.iso8601, paid_at: order.paid_at&.iso8601, shipped_at: order.shipped_at&.iso8601,
      delivered_at: order.delivered_at&.iso8601, cancelled_at: order.cancelled_at&.iso8601, refunded_at: order.refunded_at&.iso8601,
      email: order.email, currency: order.currency,
      items: order.line_items.map { |item|
        line = { title: item.product_title, variant_title: item.variant_title, catalog_id: item.variant&.catalog_id || item.sku.presence, quantity: item.quantity,
          unit_price_cents: item.unit_price_cents, line_total_cents: item.unit_price_cents * item.quantity,
          product_slug: item.variant&.product&.slug, image: (image(item.variant.product.image_for(item.variant), alt: item.product_title) if item.variant) }
        add_properties(line, item, item.variant&.product&.image_for(item.variant))
        line
      },
      subtotal_cents: order.subtotal_cents, discount_cents: order.discount_cents, discount_code: order.discount_code,
      shipping_cents: order.shipping_cents, tax_cents: order.tax_cents, total_cents: order.total_cents, refunded_cents: order.refunded_cents,
      shipping_address: { name: order.shipping_name, address1: order.shipping_address1, address2: order.shipping_address2,
        city: order.shipping_city, region: order.shipping_region, postal_code: order.shipping_postal_code, country: order.shipping_country },
      payment: { method: order.payment_method, required: order.card? && order.pending?,
        instructions: (@store.payment_instructions.presence if !order.card? && order.pending?) },
      tracking: ({ carrier: order.carrier, number: order.tracking_number, url: order.tracking_url } if order.tracking_number.present? || order.tracking_url.present?),
      reviewable_products: order.reviewable_products.map { |product| { slug: product.slug, title: product.title } }
    }
  end

  def collection(collection, product_count: nil, cover: nil)
    { slug: collection.slug, title: collection.title, description: collection.description.presence, product_count:,
      image: image(cover&.cover_image, alt: collection.title) }.compact
  end

  def review(review)
    { rating: review.rating, body: review.body, author_name: review.author_name, created_at: review.created_at.iso8601 }
  end

  def policy(id)
    { id:, title: I18n.t("policies.titles.#{id}"), body: @store.policy(id) }
  end

  # A buyer's photo (BuyerUpload): its token for the line, its size, and where to show it.
  def upload(upload)
    { token: upload.token, width: upload.width, height: upload.height }.merge(upload_urls(upload))
  end

  def page(page)
    { slug: page.slug, title: page.title, blocks: page.blocks }
  end

  def menu(menu)
    { key: menu.key, title: menu.title, items: menu.items.map { |item| { label: item["label"], url: item["url"] } } }
  end

  private
    def theme_settings
      setting = ThemeSetting.first
      return {} unless setting

      setting.resolved(image_url: ->(attachment) { url_helpers.rails_blob_url(attachment, **@url_options) })
    end

    # A product's fields, with a choice field's pictures as { id, label, thumb, large }.
    def buyer_inputs(product)
      artwork = product.artwork.attachments.index_by(&:id)
      product.buyer_inputs.map do |field|
        next field unless field["kind"] == "choice"

        field.merge("options" => field["options"].to_a.filter_map { |id| artwork[id] }.map { |art| { id: art.id, label: artwork_label(art) }.merge(artwork_urls(art)) })
      end
    end

    # What the buyer added (text with the font and color they picked, a photo, a picture, a color)
    # as labelled entries, and how it shows on the line's photo (preview), for a cart or order line.
    def add_properties(line, record, photo)
      return if record.properties.blank?

      product = record.product
      fields = product&.buyer_inputs.to_a
      kinds = fields.to_h { |field| [ field["key"], field["kind"] ] }
      uploads = BuyerUpload.where(token: record.properties.select { |key, _| kinds[key] == "photo" }.values).index_by(&:token)
      artwork = product ? product.artwork.attachments.index_by(&:id) : {}
      labels = fields.each_with_object({}) do |field, all|
        all[field["key"]] = field["label"]
        all["#{field["key"]}_font"] = "#{field["label"]} font"
        all["#{field["key"]}_color"] = "#{field["label"]} color"
      end
      line[:properties] = record.properties.filter_map do |key, value|
        next if key.end_with?("_crop") && kinds[key.delete_suffix("_crop")] == "photo"

        entry = { key:, label: labels[key] || key, value: }
        case kinds[key]
        when "photo" then (upload = uploads[value]) ? entry.merge(value: "Added").merge(upload_urls(upload)) : entry
        when "choice" then (art = artwork[value.to_i]) ? entry.merge(value: artwork_label(art)).merge(artwork_urls(art)) : entry
        else entry
        end
      end
      layers = BuyerInputs.layers(fields, record.properties).select { |layer| layer["images"].empty? || layer["images"].include?(photo&.id) }
      layers = layers.filter_map do |layer|
        layer = layer.except("images")
        case layer["kind"]
        when "photo" then (upload = uploads[layer["upload"]]) && layer.except("upload").merge("photo" => upload_urls(upload)[:large])
        when "choice" then (art = artwork[layer["artwork"]]) && layer.except("artwork").merge("picture" => artwork_urls(art)[:large])
        else layer
        end
      end
      line[:preview] = layers if layers.any? && photo
    end

    def artwork_label(art) = art.filename.base.humanize

    def artwork_urls(art)
      %i[ thumb large ].index_with { |size| url_helpers.rails_representation_url(art.variant(size), **@url_options) }
    end

    def upload_urls(upload)
      return {} unless upload.photo.attached?

      %i[ thumb large ].index_with { |size| url_helpers.rails_representation_url(upload.photo.variant(size), **@url_options) }
    end

    # { id, alt, thumb, card, large } for a photo, nil without one.
    def image(attachment, alt:)
      return unless attachment&.representable?

      { id: attachment.id, alt: }.merge(IMAGE_SIZES.index_with { |size| url_helpers.rails_representation_url(attachment.variant(size), **@url_options) })
    end

    def url_helpers = Rails.application.routes.url_helpers
end
