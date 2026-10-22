# The shop's collections, in its order, with how many products on sale each has and a photo: the
# first of its products on sale that has one. A collection's products are
# /v1/products?collection=<slug>.
class StorefrontApi::V1::CollectionsController < StorefrontApi::V1::BaseController
  def index
    counts = CollectionProduct.joins(:product).merge(visible_products).group(:collection_id).count
    covers = covers_for(visible_collections.ids)
    render json: { collections: visible_collections.ordered.map { |collection| json.collection(collection, product_count: counts.fetch(collection.id, 0), cover: covers[collection.id]) } }
  end

  def show
    collection = visible_collections.find_by!(slug: params[:id])
    render json: { collection: json.collection(collection, product_count: collection.products.merge(visible_products).count, cover: covers_for(collection.id)[collection.id]) }
  end

  private
    # { collection_id => its first product on sale with a photo }, in one query for them all.
    def covers_for(collection_ids)
      with_photos = ActiveStorage::Attachment.where(record_type: "Product", name: "images").select(:record_id)
      CollectionProduct.joins(:product).merge(visible_products).where(collection_id: collection_ids, product_id: with_photos)
        .select("DISTINCT ON (collection_products.collection_id) collection_products.*")
        .order("collection_products.collection_id, collection_products.position, collection_products.id")
        .includes(product: { images_attachments: :blob })
        .to_h { |entry| [ entry.collection_id, entry.product ] }
    end
end
