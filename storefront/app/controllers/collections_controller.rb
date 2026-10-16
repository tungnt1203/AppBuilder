class CollectionsController < ApplicationController
  def show
    @collection = storefront.collection(params[:id])
    @page = storefront.products(collection: @collection.slug, page: params[:page])
  end
end
