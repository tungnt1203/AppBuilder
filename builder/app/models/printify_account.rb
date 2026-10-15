require "net/http"

# A Printify account, read with the owner's token (BusinessSetting): its shops, for the owner
# to pick the one their apps sell from, and that shop's products, for /admin/products to import
# into one of their apps. Raises Error when Printify refuses the token or can't be reached.
module PrintifyAccount
  Error = Class.new(StandardError)
  BASE = "https://api.printify.com/v1"

  # [{ "id" => 123, "title" => "My shop" }, …]
  def self.shops(token)
    get(token, "/shops.json").map { |shop| shop.slice("id", "title") }
  end

  # One page of the shop's products, each with its cheapest price on sale and that variant's
  # cost: [[{ "id", "title", "image", "price_cents", "cost_cents" }, …], last page].
  def self.products(token, shop_id, page: 1)
    result = get(token, "/shops/#{shop_id}/products.json?limit=20&page=#{page.to_i}")
    products = Array(result["data"]).map do |product|
      cheapest = Array(product["variants"]).select { |variant| variant["is_enabled"] }.min_by { |variant| variant["price"].to_i }
      image = Array(product["images"]).find { |each| each["is_default"] } || Array(product["images"]).first
      { "id" => product["id"], "title" => product["title"], "image" => image&.dig("src"),
        "price_cents" => cheapest&.dig("price"), "cost_cents" => cheapest&.dig("cost") }
    end
    [ products, result["last_page"].to_i ]
  end

  def self.get(token, path)
    uri = URI(BASE + path)
    request = Net::HTTP::Get.new(uri, "Authorization" => "Bearer #{token}", "User-Agent" => "AppBuilder")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { |http| http.request(request) }
    raise Error, "Printify didn't accept the token (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, JSON::ParserError => error
    raise Error, "Couldn't reach Printify (#{error.class.name.demodulize})"
  end
  private_class_method :get
end
