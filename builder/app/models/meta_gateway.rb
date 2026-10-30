# Every call to Meta goes through here, with the access token the owner gave
# (Store#meta_access_token): the Conversions API (Meta::Purchase) and the ad account's daily
# spend (AdSpend::MetaImportJob).
#
# Tests replace MetaGateway.build with a fake (see test/test_helpers/meta_test_helper.rb).
class MetaGateway
  Error = Class.new(StandardError)
  # Meta refused the call (a wrong or revoked token, a wrong pixel ID): sending again won't help
  # until the owner fixes their settings.
  Refused = Class.new(Error)

  BASE = "https://graph.facebook.com/v24.0".freeze

  def self.build(token)
    new(token)
  end

  def initialize(token)
    @token = token
  end

  # Sends server events to the pixel; test_event_code shows them under Test events in Events
  # Manager instead of counting them. Returns how many Meta received.
  def send_events(pixel_id, events, test_event_code: nil)
    body = { data: events, access_token: @token, test_event_code: test_event_code.presence }.compact
    post("/#{pixel_id}/events", body).fetch("events_received", 0)
  end

  # The ad account's spend each day from `since` to `till` (dates), and the account's currency:
  # [ { Date => "12.34" }, "USD" ]. Days with no spend aren't listed.
  def daily_spend(account_id, since:, till:)
    body = get("/act_#{account_id}/insights", fields: "spend,account_currency", level: "account", time_increment: 1,
      time_range: { since: since.iso8601, until: till.iso8601 }.to_json, limit: 100)
    rows = Array(body["data"])
    [ rows.to_h { |row| [ Date.iso8601(row["date_start"]), row["spend"].to_s ] }, rows.first&.dig("account_currency") ]
  end

  private
    def get(path, params)
      uri = URI(BASE + path)
      uri.query = URI.encode_www_form(params.merge(access_token: @token))
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "AppBuilder shop"
      call(request)
    end

    def post(path, body)
      request = Net::HTTP::Post.new(URI(BASE + path))
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "AppBuilder shop"
      request.body = body.to_json
      call(request)
    end

    def call(request)
      response = Net::HTTP.start(request.uri.host, request.uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { |http| http.request(request) }
      body = response.body.present? ? JSON.parse(response.body) : {}
      return body if response.is_a?(Net::HTTPSuccess)

      raise error_for(response, body, reading: request.is_a?(Net::HTTP::Get))
    rescue JSON::ParserError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => error
      raise Error, "Meta didn't answer (#{error.class.name.demodulize})"
    end

    # reading: the ad account's spend, else purchases sent to the pixel.
    def error_for(response, body, reading: false)
      error = body.is_a?(Hash) ? body["error"].to_h : {}
      message = error["error_user_msg"].presence || error["message"].presence || "Meta answered #{response.code}"
      if reading && response.code.to_i.between?(400, 499) && response.code.to_i != 429
        Refused.new("Meta didn't let the access token read the ad account's spend (#{message}). It needs the ads_read permission on that ad account.")
      elsif error["code"] == 190 || response.code.to_i == 401
        Refused.new("Meta didn't accept the access token. Make a new one in Events Manager › your pixel › Settings › Conversions API.")
      elsif response.code.to_i.between?(400, 499) && response.code.to_i != 429
        Refused.new("Meta refused the purchases sent from the server: #{message}")
      else
        Error.new(message)
      end
    end
end
