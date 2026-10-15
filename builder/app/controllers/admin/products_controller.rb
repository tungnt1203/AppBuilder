# The owner's Printify products, from the account in their settings, to bring into one of their
# shops as drafts (PrintifyImportJob), where they check each one before it goes on sale.
class Admin::ProductsController < Admin::BaseController
  def index
    @setting = Current.user.business_setting
    @shops = Current.user.shops.order(:name)
    return unless @setting&.printify_token.present? && @setting.printify_shop_id.present?

    @page = params.fetch(:page, 1).to_i.clamp(1, 200)
    @products, @last_page = PrintifyAccount.products(@setting.printify_token, @setting.printify_shop_id, page: @page)
  rescue PrintifyAccount::Error => error
    @products, @error = [], error.message
  end

  def create
    shop = Current.user.shops.find_by!(subdomain: params.expect(:shop_id))
    ids = Array(params[:product_ids]).compact_blank.first(20)
    return redirect_to(admin_products_path, alert: "Pick the products to import.", status: :see_other) if ids.empty?

    PrintifyImportJob.perform_later(shop, ids)
    redirect_to admin_products_path(page: params[:page]), status: :see_other,
      notice: "Importing #{helpers.pluralize(ids.size, "product")} into #{shop.name} as drafts. Check each one in its admin before it goes on sale."
  end
end
