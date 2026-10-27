# The site's home page: the collections, the products buyers personalize, and the newest products.
class HomeController < ApplicationController
  def show
    @collections = storefront.collections.select { |collection| collection.product_count.to_i.positive? }.first(6)
    @products = storefront.products(per_page: 8)
    @personalized = storefront.products(per_page: 24).records.select(&:personalized?).first(4)
    # A product already in Make it yours stays out of the newest ones, unless that leaves too few.
    others = @products.records.reject { |product| @personalized.any? { |picked| picked.slug == product.slug } }
    @new_arrivals = others.size >= 4 ? others : @products.records
  end
end
