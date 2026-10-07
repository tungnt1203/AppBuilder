class CollectionsController < ApplicationController
  def show
    @collection = Collection.find_by!(slug: params[:id])
    @page = paginate(@collection.products.visible.with_attached_images.includes(:variants).order("collection_products.position"))
  end
end
