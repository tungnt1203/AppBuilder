# The discount code on the buyer's cart.
class Carts::DiscountsController < ApplicationController
  rate_limit to: 20, within: 1.minute, only: :create, with: -> { redirect_to cart_path, alert: t("carts.discounts.rate_limited") }

  def create
    return redirect_to(cart_path) unless current_cart

    storefront.apply_discount(current_cart.token, params[:code].to_s)
    redirect_to cart_path, notice: t(".notice"), status: :see_other
  rescue StorefrontKit::Invalid => error
    redirect_to cart_path, alert: error.message, status: :see_other
  end

  def destroy
    storefront.remove_discount(current_cart.token) if current_cart
    redirect_to cart_path, status: :see_other
  end
end
