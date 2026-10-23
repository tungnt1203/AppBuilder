# The site's home page: the collections, the products buyers personalize, and the newest products.
class HomeController < ApplicationController
  def show
    @collections = storefront.collections.select { |collection| collection.product_count.to_i.positive? }.first(6)
    @products = storefront.products(per_page: 8)
    @personalized = storefront.products(per_page: 24).records.select(&:personalized?).first(4)
  end
end
