# The Storefront API (/v1): what a shop's storefront calls, with its shop's key as a bearer token
# (ShopApiKey). The key picks the shop, which is then the tenant: every query sees that shop's
# data only. JSON in and out; money in cents with its currency; errors as
# { "error": { "code", "message", "fields" } }. GETs carry ETags (Rack::ETag), so a storefront
# that sends If-None-Match gets a 304 when nothing changed. docs/storefront-api.md lists it all.
class StorefrontApi::V1::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  set_current_tenant_through_filter
  before_action :authenticate_key

  rate_limit to: 600, within: 1.minute, by: -> { @api_key.id }, with: -> { error :rate_limited, "Too many requests: slow down a little", status: :too_many_requests }

  rescue_from ActiveRecord::RecordNotFound do |exception|
    error :not_found, "No #{exception.model&.underscore&.humanize&.downcase || "such thing"} here", status: :not_found
  end
  rescue_from ActionController::ParameterMissing do |exception|
    error :bad_request, exception.message, status: :bad_request
  end

  private
    attr_reader :api_key

    def authenticate_key
      @api_key = authenticate_with_http_token { |token, _options| ShopApiKey.authenticate(token) }
      return error(:unauthorized, "A valid shop key is needed (Authorization: Bearer <key>)", status: :unauthorized) unless @api_key

      set_current_tenant(ActsAsTenant.without_tenant { @api_key.shop })
    end

    def current_shop = ActsAsTenant.current_tenant
    def store = @store ||= Store.current

    def json
      @json ||= StorefrontApi::Json.new(store:, url_options: asset_url_options)
    end

    # Photos' addresses are for the buyer's browser: the Platform's public address, not the one a
    # storefront in a container reached it at.
    def asset_url_options
      if (url = Rails.configuration.x.platform_url)
        uri = URI(url)
        { host: uri.host, port: (uri.port unless uri.port == uri.default_port), protocol: "#{uri.scheme}://" }
      else
        { host: request.host, port: request.optional_port, protocol: request.protocol }
      end
    end

    def error(code, message, status:, fields: nil)
      render json: { error: { code: code.to_s, message:, fields: }.compact }, status:
    end

    # Each field's first problem, as the model words it: { "email" => "can't be blank" }.
    def field_errors(record)
      record.errors.group_by(&:attribute).transform_keys(&:to_s).except("base").transform_values { |errors| errors.first.message }
    end

    def invalid(record)
      message = record.errors.where(:base).first&.message || "Some details need fixing"
      error :invalid, message, fields: field_errors(record).presence, status: :unprocessable_entity
    end
end
