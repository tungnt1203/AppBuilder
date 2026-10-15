# What an owner sets once for all their shops: Stripe, Printify (the account and which of its
# shops) and their ad pixels. It's applied to every shop they own or administer (BusinessSync)
# when it's saved and when they open a new one. Secrets are encrypted.
class BusinessSetting < ApplicationRecord
  KEYS = %w[ stripe_secret_key printify_token printify_shop_id meta_pixel_id meta_access_token tiktok_pixel_id google_tag_id ].freeze

  belongs_to :user

  # The form's "Disconnect" boxes (Admin::SettingsController reads them).
  attr_accessor :clear_stripe_secret_key, :clear_printify_token, :clear_meta_access_token

  encrypts :stripe_secret_key, :printify_token, :meta_access_token

  normalizes :stripe_secret_key, :printify_token, :printify_shop_id, :meta_pixel_id, :meta_access_token,
    :tiktok_pixel_id, :google_tag_id, with: ->(value) { value.strip.presence }

  validates :stripe_secret_key, format: { with: /\A(sk|rk)_(test|live)_\w+\z/, message: "should start with sk_live_ or sk_test_" }, allow_nil: true
  validates :meta_pixel_id, format: { with: /\A\d{8,20}\z/, message: "is the pixel's number" }, allow_nil: true
  validates :tiktok_pixel_id, format: { with: /\A[A-Z0-9]{8,32}\z/ }, allow_nil: true
  validates :google_tag_id, format: { with: /\A(G|AW)-[A-Z0-9]{4,20}\z/, message: "looks like G-XXXX or AW-XXXX" }, allow_nil: true

  # What each shop is given: every key, blank for what isn't set (which disconnects it there).
  def payload
    KEYS.index_with { |key| public_send(key).to_s }
  end

  def configured?
    payload.values.any?(&:present?)
  end

  def stripe_test_mode?
    stripe_secret_key.to_s.match?(/\A(sk|rk)_test_/)
  end

  # "sk_test_…4242": enough to recognize a key without showing it.
  def self.masked(secret)
    "#{secret[/\A[a-z]+_(test|live)_/] || secret.first(4)}…#{secret.last(4)}" if secret.present?
  end
end
