# Sends a paid order to Printify (Printify::Fulfillment#submit!). When Printify can't be reached it
# tries again, less and less often, for about a day; the error shows on the order meanwhile, and
# staff can send it themselves.
class Order::FulfillJob < ApplicationJob
  retry_on PrintifyGateway::Unavailable, wait: :polynomially_longer, attempts: 14 do |_job, _error|
    nil # the order keeps the error for staff
  end

  def perform(order)
    Printify::Fulfillment.new(order).submit!(retry_later: true)
  end
end
