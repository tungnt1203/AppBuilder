# The products on sale (active): a page of them, in a collection, matching a search, in an order;
# and one, by its slug, with its options, variants, photos and size guide.
class StorefrontApi::V1::ProductsController < StorefrontApi::V1::BaseController
  SORTS = {
    "newest" => -> { Product.newest_first },
    "title" => -> { Product.order(:title, :id) },
    "price_asc" => -> { Product.order(Arel.sql("(SELECT MIN(price_cents) FROM variants WHERE variants.product_id = products.id) ASC, products.id")) },
    "price_desc" => -> { Product.order(Arel.sql("(SELECT MIN(price_cents) FROM variants WHERE variants.product_id = products.id) DESC, products.id")) }
  }.freeze
  PER_PAGE = 24

  def index
    products = Product.visible.search(params[:q]).merge(SORTS.fetch(params[:sort].to_s) { SORTS["newest"] }.call)
    products = products.where(id: Collection.find_by!(slug: params[:collection]).products) if params[:collection].present?
    total = products.count
    per = params.fetch(:per_page, PER_PAGE).to_i.clamp(1, 100)
    page = params.fetch(:page, 1).to_i.clamp(1, [ (total.to_f / per).ceil, 1 ].max)
    records = products.with_attached_images.includes(:variants).limit(per).offset((page - 1) * per)

    render json: { products: records.map { |product| json.product_summary(product) },
      page:, per_page: per, total:, pages: [ (total.to_f / per).ceil, 1 ].max }
  end

  def show
    product = Product.visible.with_attached_images.includes(:variants, :collections).find_by!(slug: params[:id])
    render json: { product: json.product(product) }
  end
end
