# Removes one of a product's pictures that buyers pick from (Product#artwork).
class ShopAdmin::Products::ArtworkController < ShopAdmin::BaseController
  def destroy
    product = Product.find_by!(slug: params[:product_id])
    product.artwork.find(params[:id]).purge_later
    redirect_to edit_shop_admin_product_path(product), notice: t(".notice"), status: :see_other
  end
end
