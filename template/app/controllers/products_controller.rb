class ProductsController < ApplicationController
  SORTS = {
    "newest" => { published_at: :desc, id: :desc },
    "title" => { title: :asc }
  }.freeze

  def index
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "newest"
    @page = paginate(Product.visible.search(params[:q]).order(SORTS[@sort]).with_attached_images.includes(:variants))
  end

  def show
    @product = Product.visible.with_attached_images.includes(:variants).find_by!(slug: params[:id])
    @variant = @product.variant_for(Array(params[:options])) || @product.available_variants.first || @product.variants.first
  end
end
