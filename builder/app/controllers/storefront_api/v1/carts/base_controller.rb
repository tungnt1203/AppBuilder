# What changes a cart, found by the token in the path.
class StorefrontApi::V1::Carts::BaseController < StorefrontApi::V1::BaseController
  before_action :set_cart

  private
    def set_cart
      @cart = find_cart(params[:cart_id])
    end

    def render_cart(status: :ok)
      render json: { cart: json.cart(@cart.reload.tap { |cart| cart.demo_shown = demo_shown? }) }, status:
    end
end
