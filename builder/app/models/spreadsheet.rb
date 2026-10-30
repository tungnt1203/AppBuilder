require "csv"

# The admin's lists as CSV for a spreadsheet, an email tool or an ad audience: amounts as plain
# numbers (24.00) in the shop's currency, times in the shop's time zone.
module Spreadsheet
  extend self

  def customers(buyers, currency:)
    build([ "Name", "Email", "Orders", "Spent (#{currency})", "First order", "Last order" ]) do |rows|
      buyers.each do |buyer|
        rows << [ buyer.customer_name, buyer.email, buyer.orders_count, amount(buyer.spent_cents), day(buyer.first_order_at), day(buyer.last_order_at) ]
      end
    end
  end

  def orders(orders)
    build([ "Order", "Date", "Status", "Email", "Name", "Phone", "Address", "City", "Region", "Postal code", "Country",
            "Items", "Subtotal", "Discount", "Discount code", "Shipping", "Tax", "Total", "Refunded", "Currency",
            "Payment", "Source", "Carrier", "Tracking number" ]) do |rows|
      orders.each do |order|
        rows << [ order.name, order.created_at.in_time_zone(zone).strftime("%Y-%m-%d %H:%M"), order.status, order.email, order.shipping_name, order.phone,
          [ order.shipping_address1, order.shipping_address2 ].compact_blank.join(", "), order.shipping_city, order.shipping_region,
          order.shipping_postal_code, order.shipping_country,
          order.line_items.map { |item| [ "#{item.quantity} × #{item.product_title}", item.variant_title ].compact_blank.join(" – ") }.join("; "),
          amount(order.subtotal_cents), amount(order.discount_cents), order.discount_code, amount(order.shipping_cents), amount(order.tax_cents),
          amount(order.total_cents), amount(order.refunded_cents), order.currency, order.payment_method, order.source, order.carrier, order.tracking_number ]
      end
    end
  end

  private
    # A cell starting with = + - @ is a formula to a spreadsheet: a buyer's name can't run one.
    def build(header)
      CSV.generate do |csv|
        csv << header
        rows = []
        yield rows
        rows.each { |row| csv << row.map { |cell| cell.is_a?(String) && cell.match?(/\A[=+\-@\t\r]/) ? "'#{cell}" : cell } }
      end
    end

    def amount(cents) = format("%.2f", cents.to_i / 100.0)
    def day(time) = time&.in_time_zone(zone)&.to_date&.iso8601
    def zone = ActsAsTenant.current_tenant&.time_zone || "UTC"
end
