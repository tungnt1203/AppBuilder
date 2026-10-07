# The buyer's page for their order, reached by its unguessable token (from checkout and emails).
class OrdersController < ApplicationController
  def show
    @order = Order.includes(:line_items).find_by!(token: params[:id])
    @store = Store.current
  end
end
