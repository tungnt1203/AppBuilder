# A shop at a glance, for its people's board of all their shops' orders (Admin::DashboardsController):
# the last 30 days' sales, orders, what needs action and Printify's problems, and the latest
# orders. Read inside the shop (its tenant). Buyers appear by name only.
class OrdersSummary
  RECENT = 25

  def initialize(now: Time.current)
    @now = now
  end

  def to_h
    month = Order.real.placed_since(30.days.ago(@now))
    {
      "currency" => Store.current.currency,
      "sales_cents" => month.counted_in_sales.sum(:total_cents) - month.counted_in_sales.sum(:refunded_cents),
      "orders" => month.where.not(status: "cancelled").where.not(status: "pending", payment_method: "stripe").count,
      "needs_action" => Order.real.needs_action.count,
      "problems" => Order.real.where.not(fulfillment_error: [ nil, "" ]).where(status: %w[ paid in_production ]).count,
      "margin_cents" => month.counted_in_sales.where.not(fulfillment_cost_cents: nil).sum(&:margin_cents),
      "recent" => Order.real.where.not(status: "pending", payment_method: "stripe").newest_first.limit(RECENT).map { |order| recent(order) }
    }
  end

  private
    def recent(order)
      { "number" => order.number, "token" => order.token, "name" => order.shipping_name, "status" => order.status,
        "total_cents" => order.total_cents, "currency" => order.currency, "margin_cents" => order.margin_cents,
        "problem" => order.fulfillment_error.presence, "placed_at" => order.created_at.iso8601 }
    end
end
