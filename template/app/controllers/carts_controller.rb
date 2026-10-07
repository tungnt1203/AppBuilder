class CartsController < ApplicationController
  def show
    @items = current_cart&.buyable_items.to_a
    @unavailable = current_cart ? current_cart.items.count - @items.size : 0
  end
end
