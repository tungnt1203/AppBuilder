class Admin::Orders::CancellationsController < Admin::BaseController
  include Admin::OrderTransition

  def create
    transition { @order.cancel!(by: Current.user, reason: params[:reason]) }
  end
end
