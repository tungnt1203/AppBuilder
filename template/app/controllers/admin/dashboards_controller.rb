# The shop at a glance: sales, orders waiting on someone, the latest orders.
class Admin::DashboardsController < Admin::BaseController
  def show
    sales = Order.counted_in_sales
    @sales_30_days = sales.placed_since(30.days.ago).sum(:total_cents)
    @orders_30_days = Order.where.not(status: "cancelled").placed_since(30.days.ago).count
    @orders_today = Order.placed_since(Time.current.beginning_of_day).count
    @pending_count = Order.pending.count
    @to_ship_count = Order.where(status: %w[ paid in_production ]).count
    @recent_orders = Order.newest_first.limit(8)
    @product_count = Product.active.count
    @store = Store.current
  end
end
