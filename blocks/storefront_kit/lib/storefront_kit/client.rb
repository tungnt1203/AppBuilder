require "net/http"
require "json"
require "securerandom"

module StorefrontKit
  # HTTP to the Storefront API with the shop's key. GETs are cached with their ETag: the next one
  # sends If-None-Match and takes the cached body on a 304, and when the Platform can't be reached
  # the cached body is used, so the shop stays up through a short outage. A GET can also be taken
  # from the cache without asking while it's younger than fresh_for (seconds).
  class Client
    NETWORK_ERRORS = [ Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError ].freeze

    attr_reader :url

    # transport: anything that answers call(uri, request) with a Net::HTTPResponse (tests pass a fake).
    def initialize(url:, key:, cache: nil, timeout: 8, transport: nil)
      @url, @key, @cache, @timeout = url.to_s.chomp("/"), key, cache, timeout
      @transport = transport || method(:http)
    end

    def get(path, params = {}, fresh_for: 0)
      uri = uri_for(path, params)
      key = "storefront_kit/#{uri.request_uri}"
      cached = @cache&.read(key)
      return cached[:body] if cached && fresh_for.positive? && cached[:at] > Time.now.to_f - fresh_for

      request = Net::HTTP::Get.new(uri)
      request["If-None-Match"] = cached[:etag] if cached&.dig(:etag)
      response = perform(uri, request)
      if response.code.to_i == 304 && cached
        @cache.write(key, cached.merge(at: Time.now.to_f))
        return cached[:body]
      end

      body = parse(response)
      @cache&.write(key, { etag: response["ETag"], body:, at: Time.now.to_f }) if response.code.to_i == 200
      body
    rescue Unreachable
      cached ? cached[:body] : raise
    end

    def post(path, body = {}, idempotency_key: nil) = send_body(Net::HTTP::Post, path, body, idempotency_key)
    def patch(path, body = {}) = send_body(Net::HTTP::Patch, path, body, nil)
    def delete(path) = send_body(Net::HTTP::Delete, path, nil, nil)

    private
      def send_body(klass, path, body, idempotency_key)
        uri = uri_for(path)
        request = klass.new(uri)
        request["Idempotency-Key"] = idempotency_key if idempotency_key
        if body
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(body)
        end
        parse(perform(uri, request))
      end

      def perform(uri, request)
        request["Authorization"] = "Bearer #{@key}"
        request["Accept"] = "application/json"
        request["User-Agent"] = "storefront_kit/#{VERSION}"
        @transport.call(uri, request)
      rescue *NETWORK_ERRORS => error
        raise Unreachable.new("The Platform can't be reached: #{error.message}", status: nil, code: "unreachable")
      end

      def parse(response)
        status = response.code.to_i
        body = response.body.to_s.empty? ? {} : JSON.parse(response.body)
        raise Error.for(status, body) unless status.between?(200, 299)

        body
      rescue JSON::ParserError
        raise Error.for(status, {}) unless status.between?(200, 299)

        {}
      end

      def uri_for(path, params = {})
        uri = URI("#{@url}/v1/#{path.to_s.delete_prefix("/")}")
        query = params.compact.reject { |_name, value| value.respond_to?(:empty?) && value.empty? }
        uri.query = URI.encode_www_form(query.sort.to_h) if query.any?
        uri
      end

      def http(uri, request)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: @timeout, write_timeout: @timeout) do |http|
          http.request(request)
        end
      end
  end
end
