# An Idempotency-Key a storefront sent with a checkout or a payment, and what the API answered:
# the same request sent again (a retry after a timeout, a double tap) gets that answer back
# instead of a second order or payment. The key is held from the first request on, so one sent
# twice at once is answered "in progress"; the same key with a different request is refused.
# Kept a day (ApiIdempotencyKey.expired, cleared with the abandoned carts).
class ApiIdempotencyKey < ApplicationRecord
  acts_as_tenant :shop

  KEEP_FOR = 1.day

  validates :key, length: { in: 1..255 }

  scope :expired, -> { where(created_at: ...KEEP_FOR.ago) }

  def self.fingerprint(request)
    OpenSSL::Digest::SHA256.hexdigest([ request.request_method, request.path, request.raw_post ].join("\n"))
  end

  def answered? = response_status.present?
end
