# Sends a paid order to Printify again, after it failed (a wrong address, Printify down).
class ShopAdmin::Orders::FulfillmentsController < ShopAdmin::BaseController
  include ShopAdmin::OrderTransition

  def create
    Printify::Fulfillment.new(@order).submit!
    if @order.reload.fulfillment_error
      redirect_to shop_admin_order_path(@order), alert: t(".failed", error: @order.fulfillment_error), status: :see_other
    else
      redirect_to shop_admin_order_path(@order), notice: t(".notice", number: @order.name), status: :see_other
    end
  end
end
