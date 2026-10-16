# The shop's catalog for ad networks: Meta Commerce Manager and Google Merchant Center read
# /feeds/products.xml (a Google product feed, which Meta reads too) to show products in catalog
# and shopping ads. One item per variant, with the same ids the pixels send (catalog_id).
class FeedsController < ApplicationController
  def products
    @products = all_products.map { |product| storefront.product(product.slug) }
    expires_in 1.hour, public: true
  end

  private
    def all_products
      first = storefront.products(per_page: 100)
      first.records + (2..first.pages).flat_map { |page| storefront.products(per_page: 100, page:).records }
    end
end
