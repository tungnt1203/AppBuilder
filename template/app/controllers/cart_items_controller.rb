# Adding to, changing and removing from the visitor's cart.
class CartItemsController < ApplicationController
  rate_limit to: 60, within: 1.minute, only: :create

  def create
    variant = Variant.includes(:product).find_by(id: params[:variant_id])

    if variant&.buyable?
      current_cart!.add(variant, params.fetch(:quantity, 1).to_i.clamp(1, Cart::MAX_QUANTITY))
      redirect_to cart_path, notice: t(".added", product: variant.product.title)
    else
      redirect_back_or_to products_path, alert: t(".unavailable")
    end
  end

  def update
    current_cart.update_quantity(find_item, params[:quantity])
    redirect_to cart_path, status: :see_other
  end

  def destroy
    find_item.destroy!
    redirect_to cart_path, status: :see_other
  end

  private
    def find_item
      raise ActiveRecord::RecordNotFound unless current_cart
      current_cart.items.find(params[:id])
    end
end
