# What an owner sets once in the builder for all their shops (Stripe, Printify, ad pixels),
# applied to this shop by `bin/rails shop:business_settings` with the settings as JSON in the
# TASK_INPUT variable (never in a command's arguments). Each key given changes that part
# the way /admin's settings would, and only when it differs from what the shop has; a blank value
# disconnects or clears it. Returns what happened, for the builder to show.
#
#   BusinessSettings.new(base_url: "https://cats.example.com").apply!("stripe_secret_key" => "sk_test_…")
#   # => { "stripe" => "Acme Inc (test mode)", "errors" => [] }
class BusinessSettings
  PIXELS = %w[ meta_pixel_id tiktok_pixel_id google_tag_id ].freeze

  def initialize(store = Store.current, base_url: ENV["BASE_URL"])
    @store, @base_url = store, base_url.to_s.chomp("/")
  end

  def apply!(settings)
    settings = settings.to_h.stringify_keys
    result = { "errors" => [] }
    attempt(result, "stripe") { stripe(settings["stripe_secret_key"]) } if settings.key?("stripe_secret_key")
    attempt(result, "printify") { printify(settings["printify_token"], settings["printify_shop_id"]) } if settings.key?("printify_token")
    attempt(result, "pixels") { pixels(settings) } if (PIXELS + %w[ meta_access_token ]).any? { |key| settings.key?(key) }
    result
  end

  private
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
      @store.connect_stripe!(key, webhook_url: url("/stripe/webhook")) unless @store.send(:stripe_key) == key
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
      @store.register_printify_webhooks!(url("/printify/webhook")) unless @store.printify_webhooks?(url("/printify/webhook"))
      @store.printify_shop_title.presence || "connected, pick its shop"
    end

    def pixels(settings)
      changes = settings.slice(*PIXELS).transform_values { |value| value.to_s.strip.presence }
      if settings.key?("meta_access_token") && settings["meta_access_token"].to_s.strip != @store.send(:meta_token).to_s
        changes["meta_access_token"] = settings["meta_access_token"].to_s.strip.presence
      end
      @store.update!(changes) if changes.any?
      PIXELS.filter_map { |key| key.delete_suffix("_id").tr("_", " ") if @store.public_send(key).present? }.join(", ").presence || "none"
    end

    def url(path)
      "#{@base_url}#{path}" if @base_url.present?
    end
end
