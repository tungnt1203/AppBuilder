# The buyer's page for their order, reached by its unguessable token (from checkout and emails).
# The Platform checks a card order's payment with Stripe when it's asked for it.
class OrdersController < ApplicationController
  def show
    @order = storefront.order(params[:id])
    track_purchase
  end

  private
    # Once per order and browser, when the buyer lands on it placed (paid by card, or to pay by
    # the shop's instructions).
    def track_purchase
      return unless params[:placed] && !(@order.card? && @order.pending?) && !@order.cancelled?

      tracked = Array(session[:tracked_orders])
      return if tracked.include?(@order.number)

      session[:tracked_orders] = tracked.last(19) + [ @order.number ]
      track :purchase, items: @order.items.map { |item| tracked_order_item(item) }, value_cents: @order.total_cents, order: @order
    end
end
