# The shop's site. It has no database: the shop, its catalog, the buyer's cart and orders come
# from the Platform through storefront_kit (Storefront: current_shop, current_cart, storefront).
class ApplicationController < ActionController::Base
  include Storefront, Tracking
  include Funnel # after Tracking, which remembers where the visit came from first
  # Every browser gets the site, older phones and in-app browsers (Facebook's, Instagram's) too:
  # a buyer from an ad on an iPhone a few years old must see the product, not a 406. Don't add
  # allow_browser here.

  rescue_from StorefrontKit::Unreachable, StorefrontKit::Unauthorized, with: :platform_unavailable
  rescue_from StorefrontKit::NotFound, with: :render_not_found

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    # A product taken down while its ad still runs, a mistyped address: the shop's own page, with
    # its header, a search and the newest products, so the buyer from the ad stays in the shop.
    def render_not_found(_error = nil)
      return head(:not_found) unless request.format.html?

      @products = storefront.products(per_page: 4).records
      render "errors/not_found", status: :not_found
    end

    def platform_unavailable(error)
      Rails.logger.error "The Platform didn't answer: #{error.message}"
      render "errors/unavailable", status: :service_unavailable, layout: false
    end
end
