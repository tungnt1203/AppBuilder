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
    # Up to four others from the product's first collection (else the newest), topped up from the
    # newest when it's small, and an even number so the two columns end level.
    def related_products
      collection = @product.collections.first
      picks = storefront.products(collection: collection&.slug, per_page: 5).records
      picks += storefront.products(per_page: 8).records if collection && picks.size < 5
      picks = picks.uniq(&:slug).reject { |product| product.slug == @product.slug }.first(4)
      picks.size.odd? && picks.size > 1 ? picks[0...-1] : picks
    end
end
