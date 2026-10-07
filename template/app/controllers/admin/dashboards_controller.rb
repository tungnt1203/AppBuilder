# The shop at a glance: sales, orders waiting on someone, the latest orders.
class Admin::DashboardsController < Admin::BaseController
  def show
    sales = Order.counted_in_sales
    @sales_30_days = sales.placed_since(30.days.ago).sum(:total_cents)
    placed = Order.where.not(status: "cancelled").where.not(id: Order.unpaid_card)
    @orders_30_days = placed.placed_since(30.days.ago).count
    @orders_today = placed.placed_since(Time.current.beginning_of_day).count
    @pending_count = Order.awaiting_payment.count
    @to_ship_count = Order.where(status: %w[ paid in_production ]).count
    @recent_orders = Order.where.not(id: Order.unpaid_card).newest_first.limit(8)
    @product_count = Product.active.count
    @store = Store.current
  end
end
