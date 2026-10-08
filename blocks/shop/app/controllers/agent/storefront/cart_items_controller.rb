class Agent::Storefront::CartItemsController < Agent::Storefront::BaseController
  def create
    variant = buyable_variant! or return
    cart = agent_cart!
    cart.add(variant, params.require(:quantity).to_i.clamp(1, Cart::MAX_QUANTITY))
    render json: catalog.cart_json(cart.reload)
  end

  def update
    cart = agent_cart
    if cart && (item = cart.items.find_by(variant: AgentApi::Ids.buyable_variant(params[:id])))
      cart.update_quantity(item, params.require(:quantity).to_i.clamp(1, Cart::MAX_QUANTITY))
    end
    render json: catalog.cart_json(cart&.reload)
  end

  def destroy
    cart = agent_cart
    cart&.items&.where(variant: AgentApi::Ids.buyable_variant(params[:id]))&.delete_all
    render json: catalog.cart_json(cart&.reload)
  end

  private
    # 409 "unavailable" for something that exists but can't be bought now, with the variants of
    # the same product that can.
    def buyable_variant!
      record = AgentApi::Ids.find(params.require(:product_id)) or raise ActiveRecord::RecordNotFound, "No product #{params[:product_id]}"
      if record.is_a?(Product) && record.has_options?
        raise AgentChange::NotApplicable, "#{params[:product_id]} has options; add one of its variants"
      end

      variant = record.is_a?(Product) ? record.variants.first : record
      return variant if variant&.buyable?

      siblings = variant ? variant.product.variants.select(&:buyable?).map { |sibling| AgentApi::Ids.variant(sibling) } : []
      render json: { error: "unavailable", message: "#{params[:product_id]} can't be bought right now", in_stock: siblings }, status: :conflict
      nil
    end
end
