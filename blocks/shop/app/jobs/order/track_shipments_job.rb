# Every hour: orders Printify is making are shipped once Printify has their tracking.
class Order::TrackShipmentsJob < ApplicationJob
  def perform
    return unless Store.current.printify_connected?

    Order.in_production.where.not(printify_order_id: nil).find_each { |order| Printify::Fulfillment.new(order).sync! }
  end
end
