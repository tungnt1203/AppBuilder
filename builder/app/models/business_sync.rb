# Applies an owner's business settings (BusinessSetting: Stripe, Printify, ad pixels) to one of
# the shops they run, the way its admin's settings would: each part only when it differs from
# what the shop has, a blank value disconnects or clears it. What happened is kept on the shop
# (business_sync_result) for the owner's settings page.
#
#   BusinessSync.new(shop, settings).call # => { "stripe" => "Acme Inc (test mode)", "errors" => [] }
class BusinessSync
  PIXELS = %w[ meta_pixel_id tiktok_pixel_id google_tag_id ].freeze

  def initialize(shop, settings)
    @shop, @settings = shop, settings
  end

  def call
    result = ActsAsTenant.with_tenant(@shop) { apply!(@settings.payload) }
    @shop.update!(business_synced_at: Time.current, business_sync_result: result)
    result
  end

  private
    def apply!(settings)
      @store = Store.current
      result = { "errors" => [] }
      attempt(result, "stripe") { stripe(settings["stripe_secret_key"]) }
      attempt(result, "printify") { printify(settings["printify_token"], settings["printify_shop_id"]) }
      attempt(result, "pixels") { pixels(settings) }
      result
    end

    def attempt(result, part)
      result[part] = yield
    rescue StripeGateway::Error, PrintifyGateway::Error, ActiveRecord::RecordInvalid => error
      result["errors"] << "#{part.capitalize}: #{error.message}"
    end

    def stripe(key)
      key = key.to_s.strip
      if key.empty?
        @store.disconnect_stripe! if @store.stripe_connected?
        return "not connected"
      end
      @store.connect_stripe!(key) unless @store.send(:stripe_key) == key
      "#{@store.stripe_account_name}#{" (test mode)" if @store.stripe_test_mode?}"
    end

    def printify(token, shop_id)
      token = token.to_s.strip
      if token.empty?
        @store.disconnect_printify! if @store.printify_token.present?
        return "not connected"
      end
      shops = @store.printify_token == token && @store.printify_shop_id.present? ? nil : @store.connect_printify!(token)
      if shop_id.present? && shop_id.to_s != @store.printify_shop_id
        shop = (shops || @store.printify.shops).find { |each| each["id"].to_s == shop_id.to_s } or
          raise PrintifyGateway::Error, "the Printify account has no shop #{shop_id}"
        @store.update!(printify_shop_id: shop["id"].to_s, printify_shop_title: shop["title"])
      end
      @store.printify_shop_title.presence || "connected, pick its shop"
    end

    def pixels(settings)
      changes = settings.slice(*PIXELS).transform_values { |value| value.to_s.strip.presence }
      if settings["meta_access_token"].to_s.strip != @store.send(:meta_token).to_s
        changes["meta_access_token"] = settings["meta_access_token"].to_s.strip.presence
      end
      @store.update!(changes) if changes.any?
      PIXELS.filter_map { |key| key.delete_suffix("_id").tr("_", " ") if @store.public_send(key).present? }.join(", ").presence || "none"
    end
end
