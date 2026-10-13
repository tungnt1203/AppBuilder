# A paid order's trip through Printify: its Printify items go there to be printed (and straight
# to production, unless the owner reviews orders in Printify first), the order moves to "in
# production", and once Printify ships it, the order is shipped with the tracking link and the
# buyer gets the shipped email. Items not from Printify stay with staff, as before.
class Printify::Fulfillment
  def initialize(order, store = Store.current)
    @order, @store = order, store
  end

  # Whether this order has anything for Printify to make.
  def applies?
    @store.printify_connected? && printify_items.any?
  end

  # Sends the order to Printify once; a failure is kept on the order (fulfillment_error) for
  # staff to see and send again from /admin.
  def submit!
    return unless applies? && @order.paid? && @order.printify_order_id.blank?

    id = gateway.create_order(@store.printify_shop_id, payload)
    gateway.send_to_production(@store.printify_shop_id, id) if @store.printify_send_to_production?
    @order.update!(printify_order_id: id, fulfillment_error: nil)
    @order.start_production!(message: "Printify #{id}")
  rescue PrintifyGateway::Error => error
    @order.update!(fulfillment_error: error.message)
    @order.record "fulfillment_failed", message: error.message
  end

  # Asks Printify about the order: ships it when Printify has a shipment.
  def sync!
    return unless @order.printify_order_id.present? && @order.in_production? && @store.printify

    shipment = Array(gateway.order(@store.printify_shop_id, @order.printify_order_id)["shipments"]).first
    @order.ship!(carrier: shipment["carrier"], tracking_number: shipment["number"], tracking_url: shipment["url"]) if shipment
  rescue PrintifyGateway::Error => error
    Rails.logger.warn "Couldn't check order #{@order.number} with Printify: #{error.message}"
  end

  private
    def gateway
      @gateway ||= @store.printify
    end

    def printify_items
      @order.line_items.select { |item| item.variant&.printify_variant_id && item.variant.product.printify_product_id }
    end

    def payload
      first_name, last_name = @order.shipping_name.to_s.split(" ", 2)
      {
        external_id: @order.number.to_s,
        label: @order.name,
        line_items: printify_items.map { |item|
          { product_id: item.variant.product.printify_product_id, variant_id: item.variant.printify_variant_id, quantity: item.quantity }
        },
        shipping_method: @store.printify_shipping_method,
        send_shipping_notification: false, # the shop sends its own shipped email
        address_to: {
          first_name:, last_name: last_name.presence || first_name, email: @order.email, phone: @order.phone.to_s,
          country: @order.shipping_country, region: @order.shipping_region.to_s, address1: @order.shipping_address1,
          address2: @order.shipping_address2.to_s, city: @order.shipping_city, zip: @order.shipping_postal_code.to_s
        }
      }
    end
end
