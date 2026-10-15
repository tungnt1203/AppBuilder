# The shop at a glance for its owner's builder, which shows all their shops' orders on one board:
# the last 30 days' sales, orders, what needs action and Printify's problems, and the latest
# orders. Printed by `bin/rails shop:orders_summary` as JSON. Buyers appear by name only.
class OrdersSummary
  RECENT = 25

  def initialize(now: Time.current)
    @now = now
  end

  def to_h
    month = Order.placed_since(30.days.ago(@now))
    {
      "currency" => Store.current.currency,
      "sales_cents" => month.counted_in_sales.sum(:total_cents) - month.counted_in_sales.sum(:refunded_cents),
      "orders" => month.where.not(status: "cancelled").where.not(status: "pending", payment_method: "stripe").count,
      "needs_action" => Order.needs_action.count,
      "problems" => Order.where.not(fulfillment_error: [ nil, "" ]).where(status: %w[ paid in_production ]).count,
      "margin_cents" => month.counted_in_sales.where.not(fulfillment_cost_cents: nil).sum(&:margin_cents),
      "recent" => Order.where.not(status: "pending", payment_method: "stripe").newest_first.limit(RECENT).map { |order| recent(order) }
    }
  end

  private
    def recent(order)
      { "number" => order.number, "token" => order.token, "name" => order.shipping_name, "status" => order.status,
        "total_cents" => order.total_cents, "currency" => order.currency, "margin_cents" => order.margin_cents,
        "problem" => order.fulfillment_error.presence, "placed_at" => order.created_at.iso8601 }
    end
end
