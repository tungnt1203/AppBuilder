module StorefrontKit
  # What the Platform answered instead of what was asked: its code ("invalid", "unavailable"…),
  # message and, when fields were at fault, { "email" => "is invalid" }.
  class Error < StandardError
    attr_reader :status, :code, :fields

    def initialize(message = nil, status: nil, code: nil, fields: nil)
      super(message)
      @status, @code, @fields = status, code, fields || {}
    end

    STATUSES = {} # filled in below: HTTP status => error class

    def self.for(status, body)
      error = body.is_a?(Hash) ? body["error"].to_h : {}
      klass = STATUSES.fetch(status) { status >= 500 ? Unreachable : Error }
      klass.new(error["message"] || "The Platform answered #{status}", status:, code: error["code"], fields: error["fields"])
    end
  end

  class Unauthorized < Error; end   # 401: SHOP_KEY is missing or revoked
  class NotFound < Error; end       # 404: answered as the storefront's own 404
  class Unavailable < Error; end    # 409: can't be bought now, or the same request is still running
  class Invalid < Error; end        # 422: fields hold what to fix
  class RateLimited < Error; end    # 429
  class PaymentFailed < Error; end  # 502 payment_failed: Stripe refused
  class Unreachable < Error; end    # the Platform is down or slow; GETs fall back to what's cached

  Error::STATUSES.merge!(401 => Unauthorized, 404 => NotFound, 409 => Unavailable, 422 => Invalid, 429 => RateLimited)
end
