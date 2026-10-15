class ShopAdmin::Orders::RestocksController < ShopAdmin::BaseController
  include ShopAdmin::OrderTransition

  # A refunded order's items came back to the shop.
  def create
    transition { @order.return_to_stock!(by: Current.user) }
  end
end
