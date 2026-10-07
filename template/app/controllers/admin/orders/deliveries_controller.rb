class Admin::Orders::DeliveriesController < Admin::BaseController
  include Admin::OrderTransition

  def create
    transition { @order.mark_delivered!(by: Current.user) }
  end
end
