# Every hour: orders sent to Printify move along with it (see Printify::Fulfillment#sync!).
class Order::TrackShipmentsJob < ApplicationJob
  def perform
    return unless Store.current.printify_connected?

    orders = Order.where(status: %w[ paid in_production ]).or(Order.shipped.where(shipped_at: 2.months.ago..))
    orders.where.not(printify_order_id: nil).find_each { |order| Printify::Fulfillment.new(order).sync! }
  end
end
