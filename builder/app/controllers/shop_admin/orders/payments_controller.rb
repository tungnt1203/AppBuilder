class ShopAdmin::Orders::PaymentsController < ShopAdmin::BaseController
  include ShopAdmin::OrderTransition

  def create
    transition { @order.mark_paid!(by: Current.user, reference: params[:reference]) }
  end
end
