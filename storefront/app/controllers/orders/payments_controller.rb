# Paying a card order with Stripe's Payment Element, right after checkout or from the order page
# while it waits to be paid. Stripe sends the buyer back to the order's page.
class Orders::PaymentsController < ApplicationController
  rate_limit to: 20, within: 1.minute, with: -> { redirect_to order_path(params[:order_id]), alert: t("checkouts.rate_limited") }

  def show
    @order = storefront.order(params[:order_id])
    return redirect_to(order_path(@order)) unless @order.card? && @order.payment.required?

    @payment = storefront.payment(@order.token)
  rescue StorefrontKit::Invalid, StorefrontKit::PaymentFailed => error
    redirect_to order_path(params[:order_id]), alert: error.message
  end
end
