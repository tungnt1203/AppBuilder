class Admin::Orders::RestocksController < Admin::BaseController
  include Admin::OrderTransition

  # A refunded order's items came back to the shop.
  def create
    transition { @order.return_to_stock!(by: Current.user) }
  end
end
