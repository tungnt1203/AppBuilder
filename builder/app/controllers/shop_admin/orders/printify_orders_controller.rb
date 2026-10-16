# Links an order staff made by hand in Printify (to print the text the buyer typed) to this one.
class ShopAdmin::Orders::PrintifyOrdersController < ShopAdmin::BaseController
  include ShopAdmin::OrderTransition

  def create
    if Printify::Fulfillment.new(@order).link!(params[:printify_order])
      redirect_to shop_admin_order_path(@order), notice: t(".notice", number: @order.name), status: :see_other
    else
      redirect_to shop_admin_order_path(@order), alert: t(".failed", error: @order.reload.fulfillment_error.presence || t(".not_found")), status: :see_other
    end
  end
end
