# Works out where Printify's print area sits on the product's photo (Personalization::PrintAreaGuess)
# instead of the owner drawing it, for them to check on the photo and adjust.
class ShopAdmin::Products::PrintAreasController < ShopAdmin::BaseController
  def create
    product = Product.find_by!(slug: params[:product_id])
    store = Store.current
    position = params[:position].presence_in(Product::PRINT_POSITIONS) || "front"
    found = (Personalization::PrintAreaGuess.new(product, gateway: store.printify, shop_id: store.printify_shop_id).call(position:) if product.printify_product_id && store.printify)

    if found && product.update(print_area: found)
      redirect_to edit_shop_admin_product_path(product, anchor: "print-area"), notice: t(".found"), status: :see_other
    else
      redirect_to edit_shop_admin_product_path(product, anchor: "print-area"), alert: t(".not_found"), status: :see_other
    end
  end
end
