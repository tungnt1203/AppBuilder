# A buyer's order, by its token (the order page, the links in its emails). A card order not paid
# yet is checked with Stripe first, so a buyer back from paying sees it paid.
class StorefrontApi::V1::OrdersController < StorefrontApi::V1::BaseController
  def show
    order = Order.includes(line_items: { variant: :product }).find_by!(token: params[:id])
    order.sync_card_payment!
    render json: { order: json.order(order.reload) }
  rescue StripeGateway::Error => exception
    Rails.logger.warn "Couldn't check order #{order.name}'s payment with Stripe: #{exception.message}"
    render json: { order: json.order(order) }
  end
end
