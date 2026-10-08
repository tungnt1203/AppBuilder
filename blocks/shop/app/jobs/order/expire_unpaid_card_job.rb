# Card checkouts the buyer never paid are cancelled after Order::UNPAID_CARD_EXPIRY, so they don't
# linger as pending orders. Stripe is asked first: one paid late is confirmed instead.
class Order::ExpireUnpaidCardJob < ApplicationJob
  def perform
    gateway = Store.current.stripe

    Order.unpaid_card.where(created_at: ...Order::UNPAID_CARD_EXPIRY.ago).find_each do |order|
      result = order.sync_card_payment!(gateway)
      order.cancel!(reason: "Payment not completed", notify: false) if order.pending? && (result.nil? || result[:status] != "open")
    rescue StripeGateway::Error => error
      Rails.logger.warn "Couldn't check the payment of order #{order.number}: #{error.message}"
    end
  end
end
