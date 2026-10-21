class CollectionsController < ApplicationController
  def show
    @collection = storefront.collection(params[:id])
    @sort = ProductsController::SORTS.include?(params[:sort]) ? params[:sort] : "newest"
    @page = storefront.products(collection: @collection.slug, sort: @sort, page: params[:page])
  end
end
