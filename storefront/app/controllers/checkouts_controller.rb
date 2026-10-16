# Checkout as a guest: contact, shipping address, how to pay, place the order. A card order goes
# on to its payment page (Stripe's Payment Element); a manual one to its order page.
class CheckoutsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to new_checkout_path, alert: t("checkouts.rate_limited") }

  before_action :require_items

  def new
    @checkout = CheckoutForm.new(shipping_country: default_country, payment_method: current_shop.payment_methods.first)
    @quote = storefront.quote(current_cart.token, **@checkout.to_api.slice(:shipping_country, :payment_method))
    track :initiate_checkout, items: @quote.items.map { |item| tracked_cart_item(item) }, value_cents: @quote.subtotal_cents
  end

  def create
    @checkout = CheckoutForm.new(checkout_params)
    order = storefront.place_order(current_cart.token, idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid,
      attribution: tracking_attribution, **@checkout.to_api)
    redirect_to(order.payment.required? ? order_payment_path(order) : order_path(order, placed: 1))
  rescue StorefrontKit::Invalid => error
    @checkout.add_problems(error.fields, error.message)
    @quote = storefront.quote(current_cart.token, **@checkout.to_api.slice(*SHIPPING_FIELDS))
    render :new, status: :unprocessable_entity
  end

  # The totals again for the address being filled in (Printify's shipping depends on it).
  def shipping
    return redirect_to(new_checkout_path) unless turbo_frame_request?

    quote = storefront.quote(current_cart.token, **params.permit(*SHIPPING_FIELDS).to_h.symbolize_keys.compact_blank)
    render partial: "checkouts/totals", locals: { quote:, payment_method: params[:payment_method] }
  end

  SHIPPING_FIELDS = %i[ shipping_country shipping_region shipping_postal_code payment_method ].freeze

  private
    def require_items
      redirect_to cart_path, alert: t("checkouts.empty") if current_cart.nil? || current_cart.empty?
    end

    # The first country the shop ships to, else the US when it ships there, else the first on the list.
    def default_country
      shipping = current_shop.shipping
      codes = shipping.countries.map(&:code)
      Array(shipping.ships_to).first || ("US" if codes.include?("US")) || codes.first
    end

    def checkout_params
      params.expect(checkout: CheckoutForm::FIELDS)
    end
end
