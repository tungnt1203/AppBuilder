class ProductsController < ApplicationController
  SORTS = %w[ newest price_asc price_desc title ].freeze

  def index
    @sort = SORTS.include?(params[:sort]) ? params[:sort] : "newest"
    @page = storefront.products(q: params[:q].presence, sort: @sort, page: params[:page])
    @collections = storefront.collections.select { |collection| collection.product_count.to_i.positive? }
  end

  def show
    @product = storefront.product(params[:id])
    @variant = @product.variant_for(Array(params[:options])) || @product.available_variants.first || @product.variants.first
    @reviews = storefront.reviews(@product.slug).records.first(20) if @product.rating
    @related = related_products
    track :view_content, items: [ tracked_variant(@product, @variant) ] if @variant
  end

  private
    # Others from the product's first collection, else the newest.
    def related_products
      collection = @product.collections.first
      storefront.products(collection: collection&.slug, per_page: 5).records.reject { |product| product.slug == @product.slug }.first(4)
    end
end
