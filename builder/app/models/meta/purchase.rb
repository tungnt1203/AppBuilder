# An order placed, sent to Meta from the server (Conversions API) as the same Purchase the pixel
# sends from the buyer's browser: the same event id ("purchase-<number>", see Tracking), so Meta
# counts it once, and whatever helps Meta match it to the ad the buyer came from: their email,
# phone, name and address (hashed, as Meta asks), and the browser they checked out in
# (Order#attribution: Meta's cookies, IP, user agent).
class Meta::Purchase
  def initialize(order, store = Store.current)
    @order, @store = order, store
  end

  def applies?
    @store.meta_conversions? && !@order.purchase_reported_at
  end

  # Sends it once. Raises MetaGateway::Error when Meta refuses, to try again later.
  def report!
    return unless applies?

    @store.meta.send_events(@store.meta_pixel_id, [ event ], test_event_code: @store.meta_test_event_code)
    @order.update_columns(purchase_reported_at: Time.current)
    @store.update_columns(meta_error: nil) if @store.meta_error
  end

  def event
    {
      event_name: "Purchase",
      event_time: (@order.paid_at || @order.created_at).to_i,
      event_id: "purchase-#{@order.number}",
      action_source: "website",
      event_source_url: attribution["url"],
      user_data: user_data,
      custom_data: {
        currency: @order.currency, value: (@order.total_cents / 100.0).round(2), order_id: @order.number.to_s,
        content_type: "product", content_ids: contents.map { |item| item[:id] }, contents:,
        num_items: contents.sum { |item| item[:quantity] }
      }
    }.compact
  end

  private
    def attribution
      @order.attribution.to_h
    end

    def contents
      @contents ||= @order.line_items.map do |item|
        { id: item.variant&.catalog_id || item.sku.presence || "variant-#{item.variant_id}", quantity: item.quantity,
          item_price: (item.unit_price_cents / 100.0).round(2) }
      end
    end

    # Meta's rules: trimmed and lowercased, then SHA-256; phone as digits with its country code,
    # US zip codes as their first five digits. Meta's own cookies, IP and user agent go as they are.
    def user_data
      first_name, last_name = @order.shipping_name.to_s.strip.split(/\s+/, 2)
      zip = @order.shipping_postal_code.to_s.downcase.delete(" ")
      zip = zip[0, 5] if @order.shipping_country == "US"
      {
        em: hashed(@order.email), ph: hashed(phone),
        fn: hashed(first_name), ln: hashed(last_name), ct: hashed(@order.shipping_city.to_s.downcase.delete(" ")),
        st: hashed(@order.shipping_region.to_s.downcase.delete(" ")), zp: hashed(zip), country: hashed(@order.shipping_country),
        external_id: hashed(@order.customer_id ? "customer-#{@order.customer_id}" : @order.email),
        fbp: attribution["fbp"], fbc: attribution["fbc"],
        client_ip_address: attribution["ip"], client_user_agent: attribution["user_agent"]
      }.compact_blank
    end

    # Digits with the country code; US and Canadian numbers are often written without their 1.
    def phone
      digits = @order.phone.to_s.gsub(/\D/, "")
      digits.length == 10 && %w[ US CA ].include?(@order.shipping_country) ? "1#{digits}" : digits
    end

    def hashed(value)
      value = value.to_s.strip.downcase
      [ OpenSSL::Digest::SHA256.hexdigest(value) ] if value.present?
    end
end
