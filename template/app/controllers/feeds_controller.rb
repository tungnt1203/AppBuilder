# The shop's catalog for ad networks: Meta Commerce Manager and Google Merchant Center read
# /feeds/products.xml (a Google product feed, which Meta reads too) to show products in catalog
# and shopping ads. One item per variant, with the same ids the pixels send (Variant#catalog_id).
class FeedsController < ApplicationController
  def products
    @products = Product.visible.with_attached_images.includes(:variants).order(:id)
    @store = Store.current
    expires_in 1.hour, public: true
  end
end
