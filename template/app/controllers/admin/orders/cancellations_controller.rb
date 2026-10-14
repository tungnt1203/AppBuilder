class Admin::Orders::CancellationsController < Admin::BaseController
  include Admin::OrderTransition

  def create
    transition { @order.cancel!(by: Current.user, reason: params[:reason]) }
  rescue StripeGateway::Error => error
    redirect_to admin_order_path(@order), alert: t("admin.orders.refunds.create.failed", error: error.message), status: :see_other
  end
end
