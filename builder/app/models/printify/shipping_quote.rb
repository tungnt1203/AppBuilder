# What Printify charges the shop to ship a cart's Printify items to an address, with the
# shipping method the owner picked: checkout charges the buyer that (see Checkout#shipping_cents),
# so shipping never costs the shop more than it took. Quotes are cached for a while; nil when
# the address isn't complete enough or Printify can't quote it.
class Printify::ShippingQuote
  CACHE_FOR = 30.minutes

  def initialize(store = Store.current)
    @store = store
  end

  # items: [[variant, quantity], …], only Printify's.
  def cents(items, country:, region: nil, postal_code: nil)
    return unless @store.printify_connected? && items.any? && complete?(country, region, postal_code)

    line_items = items.map { |variant, quantity| { product_id: variant.product.printify_product_id, variant_id: variant.printify_variant_id, quantity: } }
    address = { country: country.to_s.upcase, region: region.to_s, zip: postal_code.to_s.strip }
    key = [ "printify-shipping", @store.printify_shop_id, @store.printify_shipping_method, line_items, address ].to_param
    Rails.cache.fetch(key, expires_in: CACHE_FOR, skip_nil: true) { quote(line_items, address) }
  end

  # Where carriers need the region and postal code (the US, Canada, Australia), Printify does too.
  def complete?(country, region, postal_code)
    return false if country.blank?

    Region.for(country).nil? || (Region.code_for(country, region).present? && postal_code.present?)
  end

  private
    def quote(line_items, address)
      costs = @store.printify.shipping_costs(@store.printify_shop_id, line_items:,
        address_to: address.merge(region: Region.code_for(address[:country], address[:region]) || address[:region]))
      cost = costs[PrintifyGateway::SHIPPING_COST_KEYS[@store.printify_shipping_method]] || costs["standard"]
      cost&.to_i
    rescue PrintifyGateway::Error => error
      Rails.logger.warn "Printify couldn't quote shipping: #{error.message}"
      nil
    end
end
