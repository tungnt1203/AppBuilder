# The owner's Printify products, to bring into the shop (or update) with their options, prices,
# costs and mockups (Printify::Import).
class Admin::PrintifyImportsController < Admin::BaseController
  before_action :require_printify

  def index
    @page = params.fetch(:page, 1).to_i.clamp(1, 100)
    @items, @last_page = Printify::Import.new.list(page: @page)
  rescue PrintifyGateway::Error => error
    @items, @last_page = [], 1
    flash.now[:alert] = error.message
  end

  def create
    new_product = !Product.exists?(printify_product_id: params.expect(:printify_product_id))
    product = Printify::Import.new.call(params.expect(:printify_product_id))
    if new_product
      redirect_to edit_admin_product_path(product), notice: t(".imported", title: product.title), status: :see_other
    else
      redirect_to admin_printify_imports_path(page: params[:page]), notice: t(".notice", title: product.title), status: :see_other
    end
  rescue PrintifyGateway::Error, ActiveRecord::RecordInvalid => error
    redirect_to admin_printify_imports_path(page: params[:page]), alert: error.message, status: :see_other
  end

  private
    def require_printify
      redirect_to admin_printify_connection_path, alert: t("admin.printify_imports.not_connected") unless Store.current.printify_connected?
    end
end
