# Clears every shop's carts nobody has touched for 30 days, the photos buyers added that no cart or
# order has any more (a photo on an order is kept, to print it again), and the API's idempotency keys
# older than a day (config/recurring.yml runs it daily).
class Cart::CleanupJob < ApplicationJob
  def perform
    Shop.each_in_turn do
      Cart.abandoned.in_batches(of: 500) do |carts|
        CartItem.where(cart_id: carts.select(:id)).delete_all
        carts.delete_all
      end
      BuyerUpload.unused.find_each(&:destroy)
      ApiIdempotencyKey.expired.delete_all
    end
  end
end
