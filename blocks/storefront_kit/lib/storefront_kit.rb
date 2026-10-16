require "storefront_kit/version"
require "storefront_kit/errors"
require "storefront_kit/record"
require "storefront_kit/records"
require "storefront_kit/money"
require "storefront_kit/client"
require "storefront_kit/api"
require "storefront_kit/engine" if defined?(Rails::Engine)

# A shop's storefront has no database: everything it shows and sells comes from the Platform's
# Storefront API, with the shop's key. Set PLATFORM_URL and SHOP_KEY; STOREFRONT_MODE=preview
# (the builder's preview) reads the catalog fresh on every page, live caches it for a few seconds.
module StorefrontKit
  class << self
    attr_writer :api

    def api
      @api ||= Api.new(Client.new(url: platform_url, key: ENV.fetch("SHOP_KEY", ""), cache: (Rails.cache if defined?(Rails))),
        fresh_for: preview? ? 0 : 30)
    end

    def platform_url = ENV.fetch("PLATFORM_URL", "http://localhost:3000")
    def mode = ENV.fetch("STOREFRONT_MODE", "live")
    def preview? = mode == "preview"
  end
end
