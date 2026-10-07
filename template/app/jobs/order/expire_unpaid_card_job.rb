# Card checkouts the buyer never paid are cancelled after Order::UNPAID_CARD_EXPIRY, so they don't
# linger as pending orders. Stripe is asked first: one paid late is confirmed instead.
class Order::ExpireUnpaidCardJob < ApplicationJob
  def perform
    gateway = Store.current.stripe

    Order.unpaid_card.where(created_at: ...Order::UNPAID_CARD_EXPIRY.ago).find_each do |order|
      result = gateway.checkout(order.stripe_checkout_session_id) if gateway && order.stripe_checkout_session_id
      if result&.dig(:paid)
        order.confirm_card_payment!(payment_intent: result[:payment_intent])
      elsif result.nil? || result[:status] != "open"
        order.cancel!(reason: "Payment not completed")
      end
    rescue StripeGateway::Error => error
      Rails.logger.warn "Couldn't check the payment of order #{order.number}: #{error.message}"
    end
  end
end
