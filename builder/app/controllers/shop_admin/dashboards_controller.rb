# The shop at a glance: its sales over a period against the one before, by day, by product and by
# where buyers came from (ShopReport); orders waiting on someone and the latest orders.
class ShopAdmin::DashboardsController < ShopAdmin::BaseController
  def show
    @report = ShopReport.new(period: params[:period], time_zone: current_shop.time_zone)
    placed = Order.where.not(status: "cancelled").where.not(id: Order.unpaid_card)
    @orders_today = placed.placed_since(Time.current.in_time_zone(current_shop.time_zone).beginning_of_day).count
    @pending_count = Order.awaiting_payment.count
    @to_ship_count = Order.where(status: %w[ paid in_production ]).count
    @recent_orders = Order.where.not(id: Order.unpaid_card).newest_first.limit(8)
    @store = Store.current
  end
end
