class ShopAdmin::Orders::CancellationsController < ShopAdmin::BaseController
  include ShopAdmin::OrderTransition

  def create
    transition { @order.cancel!(by: Current.user, reason: params[:reason]) }
  rescue StripeGateway::Error => error
    redirect_to shop_admin_order_path(@order), alert: t("shop_admin.orders.refunds.create.failed", error: error.message), status: :see_other
  end
end
