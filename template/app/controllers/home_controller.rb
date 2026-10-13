# The site's home page: the collections and the newest products, when the app has the shop.
class HomeController < ApplicationController
  def show
    return unless shop?

    @collections = Collection.ordered.joins(:products).merge(Product.visible).distinct.limit(6)
    @products = Product.visible.newest_first.with_attached_images.includes(:variants).limit(8)
  end
end
