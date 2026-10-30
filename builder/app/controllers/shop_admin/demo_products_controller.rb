# "Add demo products", "Redraw for this shop" and "Remove demo products" on /admin/products
# (DemoCatalog): a few products with mockups to show the shop, or try buying, before the owner's
# own are in.
class ShopAdmin::DemoProductsController < ShopAdmin::BaseController
  before_action :require_administrator

  def create
    count = DemoCatalog.add!
    redirect_to shop_admin_products_path, notice: t(".notice", count:), status: :see_other
  end

  # Made again for the shop's kind, in the background (a reply from Claude, then the photos).
  def update
    DemoCatalog::RefreshJob.perform_later(current_shop)
    redirect_to shop_admin_products_path, notice: t(".notice"), status: :see_other
  end

  def destroy
    count = DemoCatalog.remove!
    redirect_to shop_admin_products_path, notice: t(".notice", count:), status: :see_other
  end
end
