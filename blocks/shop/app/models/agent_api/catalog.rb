module AgentApi
  # The shop's catalog, cart, orders and policies in the shape shopping agents read
  # (the StorefrontBackend contract of anthropics/commerce-agents). Only active products.
  class Catalog
    SORTS = {
      "price_asc" => ->(products) { products.sort_by { |product| product.price_range&.first.to_i } },
      "price_desc" => ->(products) { products.sort_by { |product| -product.price_range&.last.to_i } }
    }.freeze

    def initialize(store: Store.current, url_helpers: Rails.application.routes.url_helpers, url_options: {})
      @store, @urls, @url_options = store, url_helpers, url_options
    end

    def search(query: nil, category: nil, min_price: nil, max_price: nil, sort: nil, limit: 8)
      products = Product.visible.includes(:variants, :collections, images_attachments: :blob)
      products = products.joins(:collections).where(collections: { slug: category.to_s.parameterize }) if category.present?
      products = matching(products, query).to_a
      products.select! { |product| (low = product.price_range&.first) && low >= min_price.to_f * 100 } if min_price.present?
      products.select! { |product| (low = product.price_range&.first) && low <= max_price.to_f * 100 } if max_price.present?
      products = SORTS.fetch(sort.to_s, :itself.to_proc).call(products)
      products.first(limit.to_i.clamp(1, 50)).map { |product| product_json(product) }
    end

    def details(id)
      case (record = Ids.find(id))
      when Product
        product_json(record).merge(long_description: record.description, specs: {}, review_highlights: [],
          variants: record.has_options? ? record.variants.map { |variant| variant_json(variant) } : []) if record.active?
      when Variant
        variant_json(record).merge(long_description: record.product.description, specs: {}, review_highlights: [], variants: []) if record.product.active?
      end
    end

    def product_json(product)
      variants = product.available_variants.presence || product.variants
      {
        product_id: Ids.product(product), title: product.title, brand: Rails.configuration.x.app_name,
        price: Ids.money(variants.map(&:price_cents).min), currency: @store.currency,
        image_url: image_url(product.cover_image), category: product.collections.first&.title,
        labels: labels(product), in_stock: product.available?,
        short_description: product.description.to_s.squish.truncate(200).presence,
        options: product.options.to_h { |_slot, name, values| [ name, values ] },
        option_values: {}, variant_of: nil, url: url(:product_url, product)
      }
    end

    def variant_json(variant)
      product = variant.product
      {
        product_id: Ids.variant(variant), title: [ product.title, variant.title ].compact.join(" – "),
        brand: Rails.configuration.x.app_name, price: Ids.money(variant.price_cents), currency: @store.currency,
        image_url: image_url(product.cover_image), in_stock: variant.buyable?,
        labels: (variant.on_sale? ? [ "On sale" ] : []),
        attributes: variant.on_sale? ? { "compare_at_price" => Ids.money(variant.compare_at_price_cents).to_s } : {},
        options: {}, option_values: product.option_names.zip(variant.option_values).to_h,
        variant_of: (Ids.product(product) if product.has_options?), url: url(:product_url, product)
      }
    end

    def cart_json(cart)
      items = cart ? cart.buyable_items : []
      {
        items: items.map do |item|
          variant = item.variant
          { product_id: item.product.has_options? ? Ids.variant(variant) : Ids.product(item.product),
            title: item.product.title, price: Ids.money(variant.price_cents), quantity: item.quantity,
            image_url: image_url(item.product.cover_image),
            option_values: item.product.option_names.zip(variant.option_values).to_h,
            variant_of: (Ids.product(item.product) if item.product.has_options?) }
        end,
        currency: @store.currency,
        discount_code: cart&.discount&.code
      }
    end

    def order_json(order)
      {
        order_id: order.name, status: order_status(order), placed_at: order.created_at.iso8601,
        items: order.line_items.map do |item|
          { product_id: item.variant ? Ids.variant(item.variant) : "line-#{item.id}", title: item.product_title,
            quantity: item.quantity, price: Ids.money(item.unit_price_cents),
            option_values: item.variant&.product ? item.variant.product.option_names.zip(item.variant.option_values).to_h : {},
            variant_of: (Ids.product(item.product) if item.product&.has_options?) }
        end,
        total: Ids.money(order.total_cents), currency: order.currency,
        estimated_delivery: nil, tracking_url: order.tracking_url
      }
    end

    # The policy pages and contact details as passages, the ones mentioning the query first.
    def policies(query)
      passages = @store.published_policies.flat_map do |id|
        @store.policy(id).split(/\n{2,}/).map.with_index do |text, index|
          { policy_id: "#{id}-#{index + 1}", title: I18n.t("policies.titles.#{id}", default: id.titleize), category: id, content: text.squish }
        end
      end
      passages << contact_passage if contact_passage
      words = query.to_s.downcase.scan(/\w{3,}/)
      return passages.first(5) if words.empty?

      passages.map { |passage| [ passage, words.count { |word| passage[:content].downcase.include?(word) || passage[:title].downcase.include?(word) } ] }
        .select { |_, score| score.positive? }.sort_by { |_, score| -score }.first(5).map(&:first)
    end

    # Shipping: the shop's flat rate, free above the threshold.
    def fulfillment(ids)
      known = Array(ids).first(20).select { |id| Ids.find(id) }
      return [] if known.empty?

      eta = I18n.t("agent_api.fulfillment.eta", countries: @store.ship_to_countries.presence&.join(", ") || I18n.t("agent_api.fulfillment.anywhere"))
      options = [ { method: "shipping", eta:, fee: Ids.money(@store.shipping_first_item_cents) } ]
      if @store.free_shipping_threshold_cents
        options << { method: "shipping", eta: I18n.t("agent_api.fulfillment.free_from", amount: Ids.money(@store.free_shipping_threshold_cents)), fee: 0.0 }
      end
      options
    end

    private
      def matching(products, query)
        words = query.to_s.downcase.scan(/[[:alnum:]]+/)
        return products if words.empty?

        words.reduce(products) do |scope, word|
          like = "%#{Product.sanitize_sql_like(word)}%"
          scope.where("LOWER(products.title) LIKE :like OR LOWER(products.description) LIKE :like", like:)
        end
      end

      def labels(product)
        labels = []
        labels << "On sale" if product.variants.any?(&:on_sale?)
        labels << "Sold out" unless product.available?
        labels
      end

      def order_status(order)
        case order.status
        when "pending", "paid", "in_production" then "processing"
        when "shipped" then "shipped"
        when "delivered" then "delivered"
        when "cancelled" then "cancelled"
        when "refunded" then "refunded"
        end
      end

      def contact_passage
        lines = [ @store.contact_email, @store.contact_phone, @store.business_address ].compact_blank
        { policy_id: "contact", title: I18n.t("agent_api.contact"), category: "contact", content: lines.join(" · ") } if lines.any?
      end

      def image_url(image)
        return unless image&.representable? && @url_options[:host]

        @urls.rails_representation_url(image.variant(:large), **@url_options)
      end

      def url(helper, record)
        @urls.public_send(helper, record, **@url_options) if @url_options[:host]
      end
  end
end
