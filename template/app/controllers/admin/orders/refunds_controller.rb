class Admin::Orders::RefundsController < Admin::BaseController
  include Admin::OrderTransition

  # Card orders are refunded in Stripe too; manual ones are only marked.
  def create
    transition { @order.refund!(by: Current.user, reason: params[:reason]) }
  rescue StripeGateway::Error => error
    redirect_to admin_order_path(@order), alert: t(".failed", error: error.message), status: :see_other
  end
end
