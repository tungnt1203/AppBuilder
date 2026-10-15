class ShopAdmin::Orders::DeliveriesController < ShopAdmin::BaseController
  include ShopAdmin::OrderTransition

  def create
    transition { @order.mark_delivered!(by: Current.user) }
  end
end
