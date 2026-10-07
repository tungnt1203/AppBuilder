# "Pay now" on the order page of a card order the buyer hasn't paid yet.
class Orders::PaymentsController < ApplicationController
  include StripeCheckout

  rate_limit to: 10, within: 1.minute, with: -> { redirect_to order_path(params[:order_id]), alert: t("checkouts.rate_limited") }

  def create
    order = Order.find_by!(token: params[:order_id])
    return redirect_to(order_path(order)) unless order.card? && order.pending?

    pay_with_stripe order, cancel_url: order_url(order)
  end
end
