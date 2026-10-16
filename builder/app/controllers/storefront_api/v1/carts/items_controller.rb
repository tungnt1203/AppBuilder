# Lines of a cart: add a variant (to the line it's already on), change a line's quantity (zero
# takes it out), take a line out. Quantities stay within what's in stock.
class StorefrontApi::V1::Carts::ItemsController < StorefrontApi::V1::Carts::BaseController
  def create
    variant = Variant.find(params.require(:variant_id))
    return error(:unavailable, "#{[ variant.product.title, variant.title ].compact.join(" – ")} can't be bought right now", status: :conflict) unless variant.buyable?

    properties, problems = variant.product.buyer_properties(raw_properties)
    return error(:invalid, "Some details need fixing", fields: problems, status: :unprocessable_entity) if problems

    @cart.add(variant, params.fetch(:quantity, 1).to_i.clamp(1, Cart::MAX_QUANTITY), properties:)
    render_cart status: :created
  end

  def update
    @cart.update_quantity(@cart.items.find(params[:id]), params.require(:quantity).to_i)
    render_cart
  end

  def destroy
    @cart.items.find(params[:id]).destroy!
    @cart.touch
    render_cart
  end

  private
    def raw_properties
      value = params[:properties]
      case value
      when ActionController::Parameters then value.to_unsafe_h
      when Hash then value
      else {}
      end
    end
end
