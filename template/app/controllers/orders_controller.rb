# The buyer's page for their order, reached by its unguessable token (from checkout and emails).
class OrdersController < ApplicationController
  def show
    @order = Order.includes(:line_items).find_by!(token: params[:id])
    @store = Store.current
    check_card_payment
    track_purchase
  end

  private
    # Once per order and browser, when the buyer lands on it placed (paid by card, or to pay by
    # the store's instructions).
    def track_purchase
      return unless params[:placed] && !(@order.card? && @order.pending?) && !@order.cancelled?

      tracked = Array(session[:tracked_orders])
      return if tracked.include?(@order.number)

      session[:tracked_orders] = tracked.last(19) + [ @order.number ]
      track :purchase, items: @order.line_items.map { |line_item| tracked_line(line_item) }, value_cents: @order.total_cents, order: @order
    end

    # A card order the buyer may just have paid: ask Stripe rather than wait for the webhook,
    # which can't reach a shop without a public address (like its preview).
    def check_card_payment
      @order.sync_card_payment!(@store.stripe)
    rescue StripeGateway::Error => error
      Rails.logger.warn "Couldn't check the payment of order #{@order.number}: #{error.message}"
    end
end
