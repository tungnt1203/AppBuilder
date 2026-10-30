# Every hour, in every shop: a buyer who typed their email at checkout and left, a couple of hours
# ago and not more than a day, without ordering, gets one email with their cart and a link back to
# it (OrderMailer.cart_recovery). Never twice for a cart.
class Cart::RecoveryJob < ApplicationJob
  def perform
    Shop.each_in_turn do
      Cart.to_remind.find_each do |cart|
        next if cart.buyable_items.empty?

        cart.update_columns(recovery_sent_at: Time.current)
        OrderMailer.cart_recovery(cart).deliver_later
      end
    end
  end
end
