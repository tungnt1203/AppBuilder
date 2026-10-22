# A buyer's cart, which the storefront keeps by its token (in the buyer's session). Every change
# answers with the whole cart (StorefrontApi::Json#cart).
class StorefrontApi::V1::CartsController < StorefrontApi::V1::BaseController
  def create
    render json: { cart: json.cart(Cart.create!) }, status: :created
  end

  def show
    render json: { cart: json.cart(find_cart(params[:id])) }
  end
end
