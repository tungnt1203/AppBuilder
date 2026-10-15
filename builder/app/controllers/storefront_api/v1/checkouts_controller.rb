# Checkout of a cart: `quote` works out what it comes to for the address so far (Printify's real
# shipping once the address is complete enough), `create` places the order (Checkout#place).
# Placing is idempotent with an Idempotency-Key. A card order then needs its payment
# (/v1/orders/:token/payment); a manual one is placed and confirmed by email right away.
class StorefrontApi::V1::CheckoutsController < StorefrontApi::V1::BaseController
  include StorefrontApi::Idempotent

  FIELDS = %i[ email phone shipping_name shipping_address1 shipping_address2 shipping_city shipping_region
    shipping_postal_code shipping_country note payment_method ].freeze

  def quote
    checkout = build_checkout
    checkout.validate
    render json: { checkout: json.checkout(checkout), problems: field_errors(checkout).presence }
  end

  def create
    idempotent do
      checkout = build_checkout
      if (order = checkout.place)
        render json: { order: json.order(order) }, status: :created
      else
        invalid checkout
      end
    end
  end

  private
    def build_checkout
      cart = Cart.find_by!(token: params.require(:cart_token))
      Checkout.new(cart:, **params.permit(*FIELDS).to_h.symbolize_keys).tap do |checkout|
        checkout.attribution = attribution
        checkout.test = api_key.preview?
      end
    end

    # The buyer's browser, which the storefront passes on for Meta's Conversions API (it calls
    # from its server, so the request's own address isn't the buyer's).
    def attribution
      params.fetch(:attribution, {}).permit(:fbp, :fbc, :ip, :user_agent, :url).to_h.compact_blank
    end
end
