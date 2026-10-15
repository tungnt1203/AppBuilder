# The shop's collections, in its order, with how many products on sale each has. A collection's
# products are /v1/products?collection=<slug>.
class StorefrontApi::V1::CollectionsController < StorefrontApi::V1::BaseController
  def index
    counts = CollectionProduct.joins(:product).merge(Product.visible).group(:collection_id).count
    render json: { collections: Collection.ordered.map { |collection| json.collection(collection, product_count: counts.fetch(collection.id, 0)) } }
  end

  def show
    collection = Collection.find_by!(slug: params[:id])
    render json: { collection: json.collection(collection, product_count: collection.products.visible.count) }
  end
end
