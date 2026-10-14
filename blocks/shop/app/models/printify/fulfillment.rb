# A paid order's trip through Printify: its Printify items go there to be printed (and straight
# to production, unless the owner reviews orders in Printify first: the order then stays paid,
# so it can still be cancelled, until Printify starts it), the order moves to "in production",
# and once Printify has shipped all of it, the order is shipped with the tracking and the buyer
# gets the shipped email. Cancelling or refunding the order cancels it in Printify while
# Printify still allows it. Items not from Printify stay with staff, as before.
class Printify::Fulfillment
  # Printify's statuses for an order being made, and for one waiting on the owner.
  PRINTING = %w[ sending-to-production in-production partially-fulfilled fulfilled ].freeze
  STUCK = %w[ has-issues unfulfillable payment-not-received ].freeze

  def initialize(order, store = Store.current)
    @order, @store = order, store
  end

  # Whether this order has anything for Printify to make.
  def applies?
    @store.printify_connected? && printify_items.any?
  end

  # Sends the order to Printify once; a failure is kept on the order (fulfillment_error) for
  # staff to see and send again from /admin. When Printify already has it (sent twice at once, or
  # a retry after an answer that got lost), the shop takes that order instead of failing.
  def submit!
    return unless applies? && @order.paid? && @order.printify_order_id.blank?

    id = create_or_find_order
    @order.reload
    return unless @order.paid? && @order.printify_order_id.blank? # the other submission got there first

    @order.update!(printify_order_id: id, fulfillment_error: nil)
    sync_cost
    if @store.printify_send_to_production?
      @order.start_production!(message: "Printify #{id}")
    else
      @order.record "sent_to_printify", message: "Printify #{id}"
    end
  rescue Order::InvalidTransition
    nil
  rescue PrintifyGateway::Error => error
    @order.update!(fulfillment_error: error.message)
    @order.record "fulfillment_failed", message: error.message
  end

  # Asks Printify about the order (from the hourly check, or when Printify's webhook says it
  # changed): moves an order the owner approved in Printify to production, ships it once Printify
  # shipped all of it (Printify splits orders between print providers, each with its own
  # package), marks it delivered when every package arrived, and tells staff when Printify
  # cancelled it or needs something from them.
  def sync!
    return unless @order.printify_order_id.present? && (@order.paid? || @order.in_production? || @order.shipped?) && @store.printify

    printify_order = gateway.order(@store.printify_shop_id, @order.printify_order_id)
    status = printify_order["status"].to_s
    shipments = Array(printify_order["shipments"])
    record_cost(printify_order)
    @order.start_production!(message: "Printify") if @order.paid? && PRINTING.include?(status)
    if status == "fulfilled" && shipments.any? && @order.can_ship?
      own_items? ? printify_part_shipped(shipments) : ship(shipments)
    end
    @order.mark_delivered! if @order.shipped? && shipments.any? && shipments.all? { |shipment| shipment["delivered_at"].present? }
    cancelled_by_printify! if status == "canceled"
    stuck!(status) if STUCK.include?(status)
  rescue PrintifyGateway::Error => error
    Rails.logger.warn "Couldn't check order #{@order.number} with Printify: #{error.message}"
  end

  # Cancels the order in Printify (when the shop cancels or refunds it before it shipped).
  # Printify only allows it before printing starts; otherwise staff are told to sort it out there.
  def cancel!
    return unless @order.printify_order_id.present? && @order.shipped_at.nil? && @store.printify

    gateway.cancel_order(@store.printify_shop_id, @order.printify_order_id)
    @order.record "printify_cancelled", message: "Printify #{@order.printify_order_id}"
  rescue PrintifyGateway::Error => error
    message = I18n.t("orders.printify_not_cancelled", error: error.message)
    @order.update!(fulfillment_error: message)
    @order.record "fulfillment_failed", message:
  end

  private
    def sync_cost
      record_cost(gateway.order(@store.printify_shop_id, @order.printify_order_id))
    rescue PrintifyGateway::Error
      nil # the hourly check brings it
    end

    def create_or_find_order
      id = gateway.create_order(@store.printify_shop_id, payload)
      gateway.send_to_production(@store.printify_shop_id, id) if @store.printify_send_to_production?
      id
    rescue PrintifyGateway::Error => error
      existing = (find_existing_order if error.message.match?(/already exists/i)) or raise
      if @store.printify_send_to_production? && existing["status"] == "on-hold"
        gateway.send_to_production(@store.printify_shop_id, existing["id"])
      end
      existing["id"]
    end

    # Unique in a Printify shop the owner's other shops may send orders to as well: this shop's
    # code (Store#uid) and the order's number, "k3x9qp-1001".
    def external_id
      "#{@store.uid}-#{@order.number}"
    end

    # The Printify order made for this one (Printify keeps its external_id as shop_order_id), among the
    # shop's latest orders.
    def find_existing_order
      1.upto(3).each do |page|
        result = gateway.orders(@store.printify_shop_id, page:)
        found = Array(result["data"]).find { |order| order.dig("metadata", "shop_order_id").to_s == external_id }
        return found if found
        break if page >= result["last_page"].to_i
      end
      nil
    end

    def cancelled_by_printify!
      return unless (@order.paid? || @order.in_production?) && @order.fulfillment_error.blank?

      message = I18n.t("orders.printify_cancelled")
      @order.update!(fulfillment_error: message)
      @order.record "fulfillment_failed", message:
    end

    # Printify's bill for the order, for the owner's margin (Order#margin_cents).
    def record_cost(printify_order)
      parts = printify_order.values_at("total_price", "total_shipping", "total_tax")
      return if parts.all?(&:nil?)

      cost = parts.sum(&:to_i)
      @order.update!(fulfillment_cost_cents: cost) unless @order.fulfillment_cost_cents == cost
    end

    def stuck!(status)
      message = I18n.t("orders.printify_stuck.#{status}")
      return if @order.fulfillment_error == message

      @order.update!(fulfillment_error: message)
      @order.record "fulfillment_failed", message:
    end

    # Items the shop sends itself, in the same order as Printify's.
    def own_items?
      printify_items.any? && @order.line_items.size > printify_items.size
    end

    # Printify sent its part of an order that has the shop's own items too: staff are told (once)
    # with Printify's tracking, and the order ships when they send the rest.
    def printify_part_shipped(shipments)
      return if @order.events.exists?(action: "printify_shipped")

      @order.record "printify_shipped", message: shipments.map { |shipment| [ shipment["carrier"], shipment["number"] ].compact_blank.join(" ") }.join(", ")
    end

    # Every package's tracking: the first one's link, all of their numbers.
    def ship(shipments)
      @order.ship!(carrier: shipments.map { |shipment| shipment["carrier"] }.compact_blank.uniq.join(", "),
        tracking_number: shipments.map { |shipment| shipment["number"] }.compact_blank.join(", "),
        tracking_url: shipments.first["url"])
    end

    def gateway
      @gateway ||= @store.printify
    end

    def printify_items
      @order.line_items.select { |item| item.variant&.printify_variant_id && item.variant.product.printify_product_id }
    end

    def payload
      first_name, last_name = @order.shipping_name.to_s.split(" ", 2)
      {
        external_id:,
        label: @order.name,
        line_items: printify_items.map { |item|
          { product_id: item.variant.product.printify_product_id, variant_id: item.variant.printify_variant_id, quantity: item.quantity }
        },
        shipping_method: @store.printify_shipping_method,
        send_shipping_notification: false, # the shop sends its own shipped email
        address_to: {
          first_name:, last_name: last_name.presence || first_name, email: @order.email, phone: @order.phone.to_s,
          country: @order.shipping_country, region: Region.code_for(@order.shipping_country, @order.shipping_region) || @order.shipping_region.to_s, address1: @order.shipping_address1,
          address2: @order.shipping_address2.to_s, city: @order.shipping_city, zip: @order.shipping_postal_code.to_s
        }
      }
    end
end
