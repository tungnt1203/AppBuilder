# The card payment for an order, which the storefront confirms with Stripe's Payment Element:
# the PaymentIntent's client secret and the account's publishable key (Order#card_payment!).
# Idempotent with an Idempotency-Key, and the same order always gets the same PaymentIntent.
# A preview's orders are paid in Stripe's test mode only.
class StorefrontApi::V1::Orders::PaymentsController < StorefrontApi::V1::BaseController
  include StorefrontApi::Idempotent

  def create
    idempotent do
      order = Order.find_by!(token: params[:order_id])
      if !order.card? || !order.pending?
        error :payment_not_needed, "#{order.name} doesn't wait for a card payment", status: :unprocessable_entity
      elsif !store.card_payments?
        error :card_payments_unavailable, I18n.t("orders.stripe_not_connected"), status: :unprocessable_entity
      elsif order.test? && !store.stripe_test_mode?
        error :test_mode_unavailable, "A preview's orders are paid in Stripe's test mode: connect test keys to try paying", status: :unprocessable_entity
      else
        intent = order.card_payment!
        render json: { payment: { provider: "stripe", client_secret: intent[:client_secret], publishable_key: store.stripe_publishable_key,
          amount_cents: order.total_cents, tax_cents: order.tax_cents, currency: order.currency, test_mode: store.stripe_test_mode? } }, status: :created
      end
    end
  rescue StripeGateway::Error => exception
    error :payment_failed, exception.message, status: :bad_gateway
  end
end
