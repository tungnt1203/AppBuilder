# The link in the reminder of a cart left at checkout: the cart becomes this browser's again, as
# the buyer left it, and they land on it.
class Carts::RestoresController < ApplicationController
  def show
    cart = storefront.cart(params[:token])
    session[:cart_token] = cart.token
    redirect_to cart_path
  rescue StorefrontKit::NotFound
    redirect_to cart_path, alert: t("carts.restore.gone")
  end
end
