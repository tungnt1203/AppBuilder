# Sends the buyer to Stripe Checkout to pay a card order. Stripe sends them back to the order
# page (which checks the payment, see OrdersController) or, if they back out, to cancel_url.
module StripeCheckout
  extend ActiveSupport::Concern

  private
    def pay_with_stripe(order, cancel_url:)
      gateway = Store.current.stripe or return redirect_to(order_path(order), alert: t("orders.stripe_not_connected"))

      # Stripe fills in {CHECKOUT_SESSION_ID} itself, so it can't be escaped like a URL parameter.
      success_url = "#{order_url(order, placed: 1)}&session_id={CHECKOUT_SESSION_ID}"
      id, url = gateway.create_checkout(order, success_url:, cancel_url:)
      order.update!(stripe_checkout_session_id: id)
      redirect_to url, allow_other_host: true, status: :see_other
    rescue StripeGateway::Error => error
      Rails.logger.error "Stripe Checkout for order #{order.number} failed: #{error.message}"
      redirect_to order_path(order), alert: t("orders.payment_not_started")
    end
end
