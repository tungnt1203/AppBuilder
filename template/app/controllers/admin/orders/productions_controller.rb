class Admin::Orders::ProductionsController < Admin::BaseController
  include Admin::OrderTransition

  def create
    transition { @order.start_production!(by: Current.user) }
  end
end
