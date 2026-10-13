# Card checkouts the buyer didn't finish: once Stripe's page has expired, the buyer gets one email
# with a link to finish paying (OrderMailer#recovery), and the order is cancelled a day after it
# was placed, so it doesn't linger as pending or hold stock. Stripe is asked first: one paid late
# is confirmed instead.
class Order::ExpireUnpaidCardJob < ApplicationJob
  def perform
    gateway = Store.current.stripe

    Order.unpaid_card.where(created_at: ...Order::UNPAID_CARD_EXPIRY.ago).find_each do |order|
      result = order.sync_card_payment!(gateway)
      next unless order.pending? && (result.nil? || result[:status] != "open")

      if order.created_at < Order::UNPAID_CARD_RECOVERY.ago
        order.cancel!(reason: "Payment not completed", notify: false)
      elsif order.recovery_sent_at.nil?
        order.update!(recovery_sent_at: Time.current)
        order.record "recovery_sent"
        OrderMailer.recovery(order).deliver_later
      end
    rescue StripeGateway::Error => error
      Rails.logger.warn "Couldn't check the payment of order #{order.number}: #{error.message}"
    end
  end
end
