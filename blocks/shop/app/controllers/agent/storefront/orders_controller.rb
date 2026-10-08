# A signed-in customer's own orders. A guest has none here; an order's page link still works.
class Agent::Storefront::OrdersController < Agent::Storefront::BaseController
  def index
    orders = customer ? Order.where(customer:).newest_first.includes(line_items: { variant: :product }).limit(params.fetch(:limit, 5).to_i.clamp(1, 20)) : []
    render json: { orders: orders.map { |order| catalog.order_json(order) }, signed_in: customer.present? }
  end

  def show
    order = customer && Order.where(customer:).find_by(number: params[:id].to_s.delete_prefix("#")) or raise ActiveRecord::RecordNotFound, "No order #{params[:id]} for this customer"
    render json: catalog.order_json(order)
  end
end
