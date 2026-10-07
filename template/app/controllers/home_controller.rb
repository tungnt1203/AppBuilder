# The site's home page: the collections and the newest products.
class HomeController < ApplicationController
  def show
    @collections = Collection.ordered.joins(:products).merge(Product.visible).distinct.limit(6)
    @products = Product.visible.newest_first.with_attached_images.includes(:variants).limit(8)
  end
end
