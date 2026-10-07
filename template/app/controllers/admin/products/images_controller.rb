class Admin::Products::ImagesController < Admin::BaseController
  def destroy
    product = Product.find_by!(slug: params[:product_id])
    product.images.find(params[:id]).purge_later
    redirect_to edit_admin_product_path(product), notice: t(".notice"), status: :see_other
  end
end
