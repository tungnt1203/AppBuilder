# The buyer's page for their order, reached by its unguessable token (from checkout and emails).
class OrdersController < ApplicationController
  def show
    @order = Order.includes(:line_items).find_by!(token: params[:id])
    @store = Store.current
    check_card_payment
  end

  private
    # A card order the buyer may just have paid: ask Stripe rather than wait for the webhook,
    # which can't reach a shop without a public address (like its preview).
    def check_card_payment
      return unless @order.card? && @order.pending? && @order.stripe_checkout_session_id && (gateway = @store.stripe)

      result = gateway.checkout(@order.stripe_checkout_session_id)
      @order.confirm_card_payment!(payment_intent: result[:payment_intent]) if result[:paid]
    rescue StripeGateway::Error => error
      Rails.logger.warn "Couldn't check the payment of order #{@order.number}: #{error.message}"
    end
end
