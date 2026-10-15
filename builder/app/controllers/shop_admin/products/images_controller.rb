class ShopAdmin::Products::ImagesController < ShopAdmin::BaseController
  def destroy
    product = Product.find_by!(slug: params[:product_id])
    product.images.find(params[:id]).purge_later
    redirect_to edit_shop_admin_product_path(product), notice: t(".notice"), status: :see_other
  end
end
