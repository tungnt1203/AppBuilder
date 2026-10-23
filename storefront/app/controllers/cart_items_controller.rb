# Adding to, changing and removing from the buyer's cart. The API keeps every line within stock.
class CartItemsController < ApplicationController
  rate_limit to: 60, within: 1.minute, only: :create

  def create
    quantity = params.fetch(:quantity, 1).to_i.clamp(1, 99)
    self.current_cart = storefront.add_to_cart(current_cart!.token, variant_id: params[:variant_id], quantity:, properties: buyer_properties)
    item = current_cart.items.find { |line| line.variant.id.to_s == params[:variant_id].to_s }
    track :add_to_cart, items: [ tracked_item(item.variant.catalog_id, [ item.product.title, item.variant.title ].compact.join(" – "), item.variant.price_cents, quantity) ], redirect: true if item
    redirect_to cart_path, notice: t(".added", product: item&.product&.title)
  rescue StorefrontKit::Invalid => error
    redirect_back_or_to products_path, alert: error.message # "Name on the shirt can't be blank"
  rescue StorefrontKit::Unavailable, StorefrontKit::NotFound
    redirect_back_or_to products_path, alert: t(".unavailable")
  end

  def update
    storefront.update_cart_item(cart_token, params[:id], quantity: params[:quantity].to_i)
    redirect_to cart_path, status: :see_other
  end

  def destroy
    storefront.remove_cart_item(cart_token, params[:id])
    redirect_to cart_path, status: :see_other
  end

  private
    def cart_token
      current_cart&.token or raise StorefrontKit::NotFound.new("No cart", status: 404)
    end

    # What the buyer typed for the product's buyer inputs ("Name on the shirt").
    def buyer_properties
      value = params[:properties]
      value.respond_to?(:permit) ? value.permit!.to_h.transform_values(&:to_s).compact_blank : {}
    end
end
