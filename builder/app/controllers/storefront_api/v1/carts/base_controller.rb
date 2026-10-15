# What changes a cart, found by the token in the path.
class StorefrontApi::V1::Carts::BaseController < StorefrontApi::V1::BaseController
  before_action :set_cart

  private
    def set_cart
      @cart = Cart.find_by!(token: params[:cart_id])
    end

    def render_cart(status: :ok)
      render json: { cart: json.cart(@cart.reload) }, status:
    end
end
