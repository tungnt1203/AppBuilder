# A draft copy of a product (Product#duplicate!), opened to rename and change.
class ShopAdmin::Products::DuplicatesController < ShopAdmin::BaseController
  def create
    copy = Product.find_by!(slug: params[:product_id]).duplicate!
    redirect_to edit_shop_admin_product_path(copy), notice: t(".notice")
  end
end
