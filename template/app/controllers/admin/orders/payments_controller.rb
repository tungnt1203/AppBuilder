class Admin::Orders::PaymentsController < Admin::BaseController
  include Admin::OrderTransition

  def create
    transition { @order.mark_paid!(by: Current.user, reference: params[:reference]) }
  end
end
