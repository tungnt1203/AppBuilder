module AgentApi
  # The shop's numbers, listings and alerts in the shape the owner's assistant reads (the
  # MerchantBackend contract of anthropics/commerce-agents). Writes go through AgentChange.
  class Merchant
    PERIODS = { "last_7_days" => 7, "last_30_days" => 30, "last_90_days" => 90 }.freeze
    METRICS = %w[ sales orders average_order_value units ].freeze
    SLOW_MOVER_DAYS = 30
    DELAYED_AFTER = 5.days
    # The movement caps the assistant states before it proposes a price or a sale.
    MAX_PRICE_DELTA_PCT = 50.0
    MAX_PROMOTION_DISCOUNT_PCT = 70.0

    def initialize(store: Store.current, now: Time.current)
      @store, @now = store, now
    end

    def context
      {
        store: Rails.configuration.x.app_name, currency: @store.currency, time_zone: Time.zone.tzinfo.name,
        reporting_period: "last_30_days", periods: PERIODS.keys, metrics: METRICS,
        alerts: alert_counts,
        limitations: [
          { source: "traffic", note: "The shop doesn't record visits, so traffic and conversion aren't available." },
          { source: "campaigns", note: "Ad campaigns are run outside the shop; it can't see or change them." }
        ]
      }
    end

    def snapshot(period = nil)
      period = PERIODS.key?(period) ? period : "last_30_days"
      current, previous = range(period), range(period, back: 1)
      sales, orders = totals(current)
      previous_sales, previous_orders = totals(previous)
      {
        period:, compare_to: "previous_#{PERIODS[period]}_days", currency: @store.currency,
        sales: Ids.money(sales), orders:, average_order_value: (Ids.money(sales / orders) if orders.positive?),
        sales_change_pct: change(sales, previous_sales), orders_change_pct: change(orders, previous_orders),
        traffic: nil, conversion_rate: nil, alerts: alert_counts,
        note: "Paid orders only; the shop doesn't record visits."
      }
    end

    def metric(name, period: nil, granularity: "day", segment: nil)
      period = PERIODS.key?(period) ? period : "last_30_days"
      granularity = %w[ day week month ].include?(granularity) ? granularity : "day"
      unless METRICS.include?(name)
        return { metric: name, period:, granularity:, segment:, points: [], note: "Not recorded; available: #{METRICS.join(", ")}." }
      end

      orders = sales_scope.where(created_at: range(period)).includes(:line_items)
      orders = orders.where(id: LineItem.joins(variant: { product: :collections }).where(collections: { slug: segment.to_s.parameterize }).select(:order_id)) if segment.present?
      buckets = orders.group_by { |order| bucket(order.created_at, granularity) }
      points = bucket_dates(period, granularity).map do |date|
        group = buckets.fetch(date, [])
        { date: date.iso8601, value: value_of(name, group) }
      end
      { metric: name, unit: (name.in?(%w[ sales average_order_value ]) ? @store.currency : nil), granularity:, period:, segment:, points:,
        note: ("Segments are collections." if segment.present?) }
    end

    def search_listings(query: nil, status: nil, max_stock: nil, sort: nil, limit: 8)
      products = Product.includes(:variants, :collections, images_attachments: :blob).ordered
      products = products.search(query) if query.present?
      listings = products.to_a.map { |product| listing_json(product) }
      listings.select! { |listing| listing[:status] == status } if status.present?
      listings.select! { |listing| listing[:stock] <= max_stock.to_i } if max_stock.present?
      listings = sort_listings(listings, sort)
      listings.first(limit.to_i.clamp(1, 50))
    end

    def listing(id)
      case (record = Ids.find(id))
      when Product
        listing_json(record).merge(long_description: record.description, review_snippets: [], return_rate_pct: nil,
          missing_attributes: missing(record), variants: record.has_options? ? record.variants.map { |variant| variant_listing_json(variant) } : [])
      when Variant
        variant_listing_json(record).merge(long_description: record.product.description, review_snippets: [], missing_attributes: [], variants: [])
      end
    end

    def listing_json(product)
      tracked = product.variants.select(&:track_inventory?)
      {
        listing_id: Ids.product(product), title: product.title, status: listing_status(product),
        price: Ids.money(product.variants.map(&:price_cents).min), currency: @store.currency,
        stock: tracked.sum(&:inventory_quantity), category: product.collections.first&.title,
        content_quality: content_quality(product), short_description: product.description.to_s.squish.truncate(200).presence,
        attributes: { "tracks_stock" => tracked.any?.to_s, "sales_last_30d" => units_sold(product.variants).to_s },
        options: product.options.to_h { |_slot, name, values| [ name, values ] }, option_values: {}, variant_of: nil
      }
    end

    def variant_listing_json(variant)
      product = variant.product
      {
        listing_id: Ids.variant(variant), title: [ product.title, variant.title ].compact.join(" – "),
        status: variant_status(variant), price: Ids.money(variant.price_cents), currency: @store.currency,
        stock: variant.track_inventory? ? variant.inventory_quantity : 0,
        attributes: { "sku" => variant.sku.to_s, "tracks_stock" => variant.track_inventory?.to_s, "sales_last_30d" => units_sold([ variant ]).to_s }.compact_blank,
        options: {}, option_values: product.option_names.zip(variant.option_values).to_h,
        variant_of: (Ids.product(product) if product.has_options?)
      }
    end

    def inventory_alerts
      threshold = @store.low_stock_threshold
      low = Variant.includes(:product).where(track_inventory: true, available: true).where(inventory_quantity: ..threshold)
        .select { |variant| variant.product.active? }.map do |variant|
        sold = units_sold([ variant ])
        alert_json(variant, "low_stock", threshold:, sales_last_30d: sold, days_of_cover: (variant.inventory_quantity / (sold / 30.0)).round(1).then { |days| days if sold.positive? })
      end
      sold_ids = LineItem.joins(:order).merge(sales_scope).where(orders: { created_at: SLOW_MOVER_DAYS.days.ago(@now).. }).distinct.pluck(:variant_id)
      slow = Product.visible.where(published_at: ..SLOW_MOVER_DAYS.days.ago(@now)).includes(:variants)
        .reject { |product| product.variants.any? { |variant| sold_ids.include?(variant.id) } }
        .map { |product| alert_json(product.variants.first, "slow_mover", sales_last_30d: 0, product:) }
      low + slow
    end

    # Orders paid but not shipped after DELAYED_AFTER, and open orders with a note from the buyer.
    def order_issues
      delayed = Order.where(status: %w[ paid in_production ]).where(paid_at: ..DELAYED_AFTER.ago(@now)).map do |order|
        { issue_id: "delayed-#{order.number}", order_id: order.name, kind: "delayed", opened_at: (order.paid_at + DELAYED_AFTER).iso8601,
          summary: "Paid #{((@now - order.paid_at) / 1.day).floor} days ago and not shipped yet." }
      end
      notes = Order.where(status: %w[ pending paid in_production ]).where.not(note: [ nil, "" ]).where.not(payment_method: "stripe", status: "pending").map do |order|
        { issue_id: "note-#{order.number}", order_id: order.name, kind: "buyer_message", opened_at: order.created_at.iso8601,
          summary: "The buyer left a note with this order.", buyer_message_excerpt: order.note.squish.truncate(200) }
      end
      delayed + notes
    end

    def pricing(id)
      case (record = Ids.find(id))
      when Product
        contexts = record.variants.map { |variant| variant_pricing(variant) }
        contexts.min_by { |context| context[:current_price] }.merge(listing_id: Ids.product(record), option_values: {}, variants: record.has_options? ? contexts : [])
      when Variant then variant_pricing(record)
      end
    end

    def alert_counts
      { low_stock: Variant.where(track_inventory: true, available: true).where(inventory_quantity: ..@store.low_stock_threshold).count,
        slow_movers: 0, order_issues: order_issues.size, pending_changes: AgentChange.staged.count }
    end

    private
      def sales_scope = Order.counted_in_sales

      def range(period, back: 0)
        days = PERIODS.fetch(period)
        finish = @now - (days * back).days
        (finish - days.days)..finish
      end

      def totals(range)
        orders = sales_scope.where(created_at: range)
        [ orders.sum(:total_cents), orders.count ]
      end

      def change(current, previous)
        ((current - previous) * 100.0 / previous).round(1) if previous.positive?
      end

      def bucket(time, granularity)
        date = time.in_time_zone.to_date
        { "day" => date, "week" => date.beginning_of_week, "month" => date.beginning_of_month }.fetch(granularity)
      end

      def bucket_dates(period, granularity)
        range(period).then { |range| (range.begin.to_date..range.end.to_date) }.map { |date| bucket(date.in_time_zone, granularity) }.uniq
      end

      def value_of(name, orders)
        case name
        when "sales" then Ids.money(orders.sum(&:total_cents))
        when "orders" then orders.size
        when "units" then orders.sum { |order| order.line_items.sum(&:quantity) }
        when "average_order_value" then orders.any? ? Ids.money(orders.sum(&:total_cents) / orders.size) : 0.0
        end
      end

      def units_sold(variants)
        LineItem.joins(:order).merge(sales_scope).where(orders: { created_at: 30.days.ago(@now).. }, variant_id: variants.map(&:id)).sum(:quantity)
      end

      def listing_status(product)
        if product.draft? then "draft"
        elsif product.archived? || product.variants.none?(&:available?) then "paused"
        elsif !product.available? then "out_of_stock"
        else "active"
        end
      end

      def variant_status(variant)
        if variant.product.draft? then "draft"
        elsif variant.product.archived? || !variant.available? then "paused"
        elsif !variant.in_stock? then "out_of_stock"
        else "active"
        end
      end

      def missing(product)
        [ ("description" if product.description.to_s.squish.length < 40), ("photos" if product.images.none?) ].compact
      end

      def content_quality(product)
        { 0 => "good", 1 => "needs_work" }.fetch(missing(product).size, "poor")
      end

      def sort_listings(listings, sort)
        case sort
        when "stock_asc" then listings.sort_by { |listing| listing[:stock] }
        when "price_asc" then listings.sort_by { |listing| listing[:price] }
        when "price_desc" then listings.sort_by { |listing| -listing[:price] }
        when "sales_desc" then listings.sort_by { |listing| -listing[:attributes]["sales_last_30d"].to_i }
        else listings
        end
      end

      def alert_json(variant, kind, product: variant.product, **figures)
        { listing_id: product.has_options? && kind == "low_stock" ? Ids.variant(variant) : Ids.product(product),
          title: kind == "low_stock" ? [ product.title, variant.title ].compact.join(" – ") : product.title, kind:,
          option_values: kind == "low_stock" ? product.option_names.zip(variant.option_values).to_h : {},
          variant_of: (Ids.product(product) if product.has_options? && kind == "low_stock"),
          stock: kind == "low_stock" ? variant.inventory_quantity : product.variants.select(&:track_inventory?).sum(&:inventory_quantity),
          storefront_visible: product.active? && variant.sellable?, **figures }
      end

      def variant_pricing(variant)
        cost = variant.cost_cents
        {
          listing_id: Ids.variant(variant), current_price: Ids.money(variant.price_cents), currency: @store.currency,
          unit_cost: (Ids.money(cost) if cost), margin_pct: (((variant.price_cents - cost) * 100.0 / variant.price_cents).round(1) if cost && variant.price_cents.positive?),
          min_price: (Ids.money(cost) if cost), min_price_basis: ("cost" if cost),
          max_price_delta_pct: MAX_PRICE_DELTA_PCT, max_promotion_discount_pct: MAX_PROMOTION_DISCOUNT_PCT,
          last_changed: variant.updated_at.to_date.iso8601,
          option_values: variant.product.option_names.zip(variant.option_values).to_h, variants: []
        }
      end
  end
end
