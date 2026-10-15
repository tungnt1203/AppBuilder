class ShopAdmin::Orders::ProductionsController < ShopAdmin::BaseController
  include ShopAdmin::OrderTransition

  def create
    transition { @order.start_production!(by: Current.user) }
  end
end
