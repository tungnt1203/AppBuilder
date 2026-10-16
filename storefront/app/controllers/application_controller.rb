# The shop's site. It has no database: the shop, its catalog, the buyer's cart and orders come
# from the Platform through storefront_kit (Storefront: current_shop, current_cart, storefront).
class ApplicationController < ActionController::Base
  include Storefront, Tracking
  # Every browser gets the site, older phones and in-app browsers (Facebook's, Instagram's) too:
  # a buyer from an ad on an iPhone a few years old must see the product, not a 406. Don't add
  # allow_browser here.

  rescue_from StorefrontKit::Unreachable, StorefrontKit::Unauthorized, with: :platform_unavailable

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def platform_unavailable(error)
      Rails.logger.error "The Platform didn't answer: #{error.message}"
      render "errors/unavailable", status: :service_unavailable, layout: false
    end
end
