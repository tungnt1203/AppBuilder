# The visitor's cart, kept by a signed cookie. Only made when something is added, so browsing
# leaves no empty carts behind.
module CurrentCart
  extend ActiveSupport::Concern

  included do
    helper_method :current_cart, :cart_item_count
  end

  private
    def current_cart
      return @current_cart if defined?(@current_cart)
      @current_cart = Cart.find_by(id: cookies.signed[:cart_id]) if cookies.signed[:cart_id]
    end

    def current_cart!
      current_cart || Cart.create!.tap do |cart|
        @current_cart = cart
        cookies.signed.permanent[:cart_id] = { value: cart.id, httponly: true, same_site: :lax }
      end
    end

    def cart_item_count
      current_cart&.item_count.to_i
    end
end
