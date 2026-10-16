# What every storefront controller has: the shop (current_shop), the buyer's cart, kept by its
# token in the session (current_cart, current_cart! to make one), and storefront, the API.
# Include it in ApplicationController.
module Storefront
  extend ActiveSupport::Concern

  included do
    helper_method :current_shop, :current_cart, :cart_item_count, :storefront
  end

  private
    def storefront = StorefrontKit.api

    def current_shop
      @current_shop ||= storefront.shop
    end

    # The buyer's cart, or nil before they add anything (or once the Platform forgot it).
    def current_cart
      return @current_cart if defined?(@current_cart)

      @current_cart = (storefront.cart(session[:cart_token]) if session[:cart_token])
    rescue StorefrontKit::NotFound
      session.delete(:cart_token)
      @current_cart = nil
    end

    def current_cart!
      current_cart || begin
        @current_cart = storefront.create_cart
        session[:cart_token] = @current_cart.token
        @current_cart
      end
    end

    # After a change, the cart the API answered with is the current one.
    def current_cart=(cart)
      @current_cart = cart
    end

    def cart_item_count = current_cart&.item_count.to_i
end
