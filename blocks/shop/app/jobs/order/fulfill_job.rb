# Sends a paid order to Printify (Printify::Fulfillment#submit!).
class Order::FulfillJob < ApplicationJob
  def perform(order)
    Printify::Fulfillment.new(order).submit!
  end
end
