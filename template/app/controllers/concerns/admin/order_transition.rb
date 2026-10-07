# Shared by the controllers that move an order to its next status (Admin::Orders::*Controller).
module Admin::OrderTransition
  extend ActiveSupport::Concern

  included do
    before_action :set_order
  end

  private
    def set_order
      @order = Order.find_by!(token: params[:order_id])
    end

    def transition
      yield
      redirect_to admin_order_path(@order), notice: t(".notice", number: @order.name), status: :see_other
    rescue Order::InvalidTransition
      redirect_to admin_order_path(@order), alert: t("admin.orders.invalid_transition", number: @order.name, status: @order.reload.status), status: :see_other
    end
end
