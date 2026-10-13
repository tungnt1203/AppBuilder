# The shop (catalog, cart, checkout, orders) is on unless config.x.shop is off, for apps that sell
# nothing: a club, a lending shed, a festival, a portfolio. Off, its routes don't match (404, see
# config/routes.rb) and the site and /admin don't link to them.
module ShopSwitch
  extend ActiveSupport::Concern

  # The routes' constraint: the shop's pages exist only while it's on.
  ON = ->(_request) { Rails.configuration.x.shop }

  included do
    helper_method :shop?
  end

  private
    def shop?
      Rails.configuration.x.shop
    end
end
