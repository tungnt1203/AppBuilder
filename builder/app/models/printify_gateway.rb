# Every call to Printify goes through here, with the owner's personal access token
# (Store#printify). Printify prints and ships the shop's products: the shop imports them from it
# (Printify::Import), sends it paid orders and asks it for their shipments (Printify::Fulfillment).
#
# Tests replace PrintifyGateway.build with a fake (see test/test_helpers/printify_test_helper.rb).
class PrintifyGateway
  Error = Class.new(StandardError)

  BASE = "https://api.printify.com/v1".freeze
  SHIPPING_METHODS = { 1 => "Standard", 2 => "Priority", 3 => "Printify Express", 4 => "Economy" }.freeze
  # Each method's name in Printify's shipping costs (#shipping_costs).
  SHIPPING_COST_KEYS = { 1 => "standard", 2 => "priority", 3 => "printify_express", 4 => "economy" }.freeze

  def self.build(token)
    new(token)
  end

  def initialize(token)
    @token = token
  end

  # [{ "id" => 123, "title" => "My shop", "sales_channel" => "custom_integration" }]
  def shops
    get("/shops.json")
  end

  # One page of a shop's products: { "data" => [...], "last_page" => 3 }.
  def products(shop_id, page: 1)
    get("/shops/#{shop_id}/products.json?limit=50&page=#{page.to_i}")
  end

  def product(shop_id, product_id)
    get("/shops/#{shop_id}/products/#{product_id}.json")
  end

  # Returns Printify's order id.
  def create_order(shop_id, order)
    post("/shops/#{shop_id}/orders.json", order).fetch("id")
  end

  # One page of the shop's orders, newest first: { "data" => [...], "last_page" => 3 }.
  def orders(shop_id, page: 1)
    get("/shops/#{shop_id}/orders.json?limit=50&page=#{page.to_i}")
  end

  def send_to_production(shop_id, order_id)
    post("/shops/#{shop_id}/orders/#{order_id}/send_to_production.json", {})
  end

  # What Printify charges the shop to ship these items there, in cents, by shipping method:
  # { "standard" => 475, "express" => 1299, … } (methods it can't use there are left out).
  def shipping_costs(shop_id, line_items:, address_to:)
    post("/shops/#{shop_id}/orders/shipping.json", { line_items:, address_to: })
  end

  # Printify only cancels an order it hasn't started printing (on hold, or not paid yet).
  def cancel_order(shop_id, order_id)
    post("/shops/#{shop_id}/orders/#{order_id}/cancel.json", {})
  end

  def order(shop_id, order_id)
    get("/shops/#{shop_id}/orders/#{order_id}.json")
  end

  # [{ "id" => "…", "topic" => "order:updated", "url" => "https://…", "shop_id" => 123 }]
  def webhooks(shop_id)
    get("/shops/#{shop_id}/webhooks.json")
  end

  # Printify posts each topic's events to url, signed with secret (see .valid_signature?).
  # Returns the webhook's id.
  def create_webhook(shop_id, topic:, url:, secret:)
    post("/shops/#{shop_id}/webhooks.json", { topic:, url:, secret: }).fetch("id")
  end

  def delete_webhook(shop_id, id, host:)
    request(Net::HTTP::Delete.new(URI("#{BASE}/shops/#{shop_id}/webhooks/#{id}.json?host=#{CGI.escape(host.to_s)}")))
  end

  # Whether a webhook's body came from Printify: its X-Pfy-Signature header is "sha256=" and the
  # body's HMAC-SHA256 with the webhook's secret.
  def self.valid_signature?(body, header, secret)
    return false if secret.blank? || header.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, body)}"
    ActiveSupport::SecurityUtils.secure_compare(expected, header.to_s)
  end

  # A mockup photo from Printify's image servers, as an IO to attach (following a few redirects).
  def download(url, redirects: 3)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) { |http| http.get(uri.request_uri) }
    if response.is_a?(Net::HTTPRedirection) && redirects.positive? && response["location"].present?
      return download(URI.join(url, response["location"]).to_s, redirects: redirects - 1)
    end
    raise Error, "Couldn't download a mockup (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

    StringIO.new(response.body)
  rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => error
    raise Error, "Couldn't download a mockup (#{error.class.name.demodulize})"
  end

  private
    def get(path) = request(Net::HTTP::Get.new(URI(BASE + path)))

    def post(path, body)
      request(Net::HTTP::Post.new(URI(BASE + path)).tap { |request| request.body = body.to_json })
    end

    def request(request)
      request["Authorization"] = "Bearer #{@token}"
      request["Content-Type"] = "application/json;charset=utf-8"
      request["User-Agent"] = "AppBuilder shop"
      response = Net::HTTP.start(request.uri.host, request.uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { |http| http.request(request) }
      body = response.body.present? ? JSON.parse(response.body) : {}
      return body if response.is_a?(Net::HTTPSuccess)

      raise Error, error_message(response, body)
    rescue JSON::ParserError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => error
      raise Error, "Printify didn't answer (#{error.class.name.demodulize})"
    end

    def error_message(response, body)
      case response.code.to_i
      when 401, 403 then "Printify didn't accept the token. Make a new one in Printify › My profile › Connections."
      when 429 then "Printify is busy (too many requests). Try again in a minute."
      else
        details = body.is_a?(Hash) ? [ body["error"], body["message"], body.dig("errors", "reason") ].compact.join(": ") : nil
        details.presence || "Printify answered #{response.code}"
      end
    end
end
