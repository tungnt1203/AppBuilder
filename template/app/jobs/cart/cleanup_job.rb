# Clears carts nobody has touched for 30 days (config/recurring.yml runs it daily).
class Cart::CleanupJob < ApplicationJob
  def perform
    Cart.abandoned.in_batches(of: 500) do |carts|
      CartItem.where(cart_id: carts.select(:id)).delete_all
      carts.delete_all
    end
  end
end
