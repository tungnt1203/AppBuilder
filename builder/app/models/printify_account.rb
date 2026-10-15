require "net/http"

# The shops of a Printify account, for the owner to pick the one their apps sell from
# (BusinessSetting). [{ "id" => 123, "title" => "My shop" }, …]; raises Error when Printify
# refuses the token.
module PrintifyAccount
  Error = Class.new(StandardError)
  URL = URI("https://api.printify.com/v1/shops.json")

  def self.shops(token)
    request = Net::HTTP::Get.new(URL, "Authorization" => "Bearer #{token}", "User-Agent" => "AppBuilder")
    response = Net::HTTP.start(URL.host, URL.port, use_ssl: true, open_timeout: 10, read_timeout: 20) { |http| http.request(request) }
    raise Error, "Printify didn't accept the token (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).map { |shop| shop.slice("id", "title") }
  rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, JSON::ParserError => error
    raise Error, "Couldn't reach Printify (#{error.class.name.demodulize})"
  end
end
