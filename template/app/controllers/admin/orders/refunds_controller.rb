class Admin::Orders::RefundsController < Admin::BaseController
  include Admin::OrderTransition

  def create
    transition { @order.refund!(by: Current.user, reason: params[:reason]) }
  end
end
