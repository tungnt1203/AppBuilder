# Checkout as a guest: contact, shipping address, review, place the order.
class CheckoutsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to new_checkout_path, alert: t("checkouts.rate_limited") }

  before_action :require_items

  def new
    @checkout = Checkout.new(cart: current_cart, **prefill)
  end

  def create
    @checkout = Checkout.new(cart: current_cart, **checkout_params)
    @checkout.customer = Current.customer if customer_signed_in?

    if order = @checkout.place
      redirect_to order_path(order, placed: 1)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def require_items
      redirect_to cart_path, alert: t("checkouts.empty") if current_cart.nil? || current_cart.empty?
    end

    def checkout_params
      params.expect(checkout: Checkout.attribute_names.map(&:to_sym)).to_h.symbolize_keys
    end

    def prefill
      if customer_signed_in?
        { email: Current.customer.email_address, shipping_name: Current.customer.name }
      else
        { shipping_country: Store.current.ship_to_countries.first || "US" }
      end
    end
end
