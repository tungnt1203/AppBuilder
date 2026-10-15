# The key a storefront calls the platform's Storefront API with: it reads its shop's catalog and
# content and runs its carts and checkouts, nothing else. "preview" keys are for the builder's
# preview (test-mode checkout, never sent to Printify). Only a digest is kept: the key is shown
# once, when it's made (#token).
class ShopApiKey < ApplicationRecord
  KINDS = %w[ storefront preview ].freeze
  PREFIX = { "storefront" => "sk_shop_", "preview" => "sk_preview_" }.freeze

  acts_as_tenant :shop

  attr_reader :token

  validates :kind, inclusion: { in: KINDS }

  before_validation :generate_token, on: :create

  scope :active, -> { where(revoked_at: nil) }

  # The active key with this token, from any shop (the API sets the tenant from it), or nil.
  def self.authenticate(token)
    return if token.blank?

    key = ActsAsTenant.without_tenant { active.find_by(token_digest: digest(token)) }
    key&.touch(:last_used_at)
    key
  end

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def preview? = kind == "preview"

  private
    def generate_token
      @token = "#{PREFIX.fetch(kind, "sk_shop_")}#{SecureRandom.base58(32)}"
      self.token_digest = self.class.digest(@token)
      self.token_hint = @token.last(4)
    end
end
