# Clears every shop's carts nobody has touched for 30 days, and the API's idempotency keys older than
# a day (config/recurring.yml runs it daily).
class Cart::CleanupJob < ApplicationJob
  def perform
    Shop.each_in_turn do
      Cart.abandoned.in_batches(of: 500) do |carts|
        CartItem.where(cart_id: carts.select(:id)).delete_all
        carts.delete_all
      end
      ApiIdempotencyKey.expired.delete_all
    end
  end
end
