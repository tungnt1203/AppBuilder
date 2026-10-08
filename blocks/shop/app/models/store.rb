# The shop's settings, one row: currency, shipping rates, where it ships, how buyers pay, the
# shop's policies. Store.current everywhere; the owner changes it at /admin/settings.
class Store < ApplicationRecord
  include MoneyAttributes

  # Currencies the shop can sell in, with how prices are written.
  CURRENCIES = {
    "USD" => { unit: "$", precision: 2 },
    "EUR" => { unit: "€", precision: 2 },
    "GBP" => { unit: "£", precision: 2 },
    "CAD" => { unit: "CA$", precision: 2 },
    "AUD" => { unit: "A$", precision: 2 },
    "VND" => { unit: "₫", precision: 0, format: "%n %u" }
  }.freeze

  # The pages every shop needs (Stripe, ad networks and buyers look for them), at /policies/:id.
  POLICIES = { "refund" => :refund_policy, "shipping" => :shipping_policy, "privacy" => :privacy_policy, "terms" => :terms_of_service }.freeze

  money_attribute :shipping_first_item, :shipping_additional_item, :free_shipping_threshold

  encrypts :stripe_secret_key, :stripe_webhook_secret

  validates :currency, inclusion: { in: CURRENCIES.keys }
  validates :shipping_first_item_cents, :shipping_additional_item_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :free_shipping_threshold_cents, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :contact_email, format: { with: EMAIL_FORMAT }, allow_blank: true
  validates :contact_phone, length: { maximum: 50 }
  validates :business_address, length: { maximum: 500 }
  validates :refund_policy, :shipping_policy, :privacy_policy, :terms_of_service, length: { maximum: 50_000 }
  validate :countries_are_known

  normalizes :ship_to_countries, with: ->(codes) { Array(codes).map { |code| code.to_s.strip.upcase }.compact_blank.uniq.sort }

  def self.current
    first || create!
  end

  # Flat-rate shipping: one price for the first item, another for each one after it, free above
  # the threshold.
  def shipping_cents_for(item_count:, subtotal_cents:)
    return 0 if item_count.zero?
    return 0 if free_shipping_threshold_cents && subtotal_cents >= free_shipping_threshold_cents

    shipping_first_item_cents + shipping_additional_item_cents * (item_count - 1)
  end

  # Empty means anywhere.
  def ships_to?(country)
    ship_to_countries.empty? || ship_to_countries.include?(country.to_s.upcase)
  end

  def countries_for_checkout
    codes = ship_to_countries.presence || Country.codes
    Country.options(codes)
  end

  def ship_to_countries_text
    ship_to_countries.join(", ")
  end

  def ship_to_countries_text=(text)
    self.ship_to_countries = text.to_s.split(/[\s,]+/)
  end

  def money_format
    CURRENCIES.fetch(currency)
  end

  # How buyers can pay at checkout, the first one picked by default: "stripe" (card, on Stripe
  # Checkout) once the owner connected Stripe, "manual" (the payment instructions, the owner
  # marks the order paid) unless they turned it off. Never empty.
  def payment_methods
    methods = []
    methods << "stripe" if stripe_connected?
    methods << "manual" if manual_payments? || methods.empty?
    methods
  end

  def stripe_connected?
    stripe_key.present?
  end

  def stripe
    StripeGateway.build(stripe_key) if stripe_connected?
  end

  # Checks the key with Stripe, saves it, and registers the webhook when the shop has a public
  # https address (webhook_url nil otherwise: payments are still confirmed when buyers come back
  # from Stripe). Raises StripeGateway::Error when Stripe refuses the key.
  def connect_stripe!(secret_key, webhook_url: nil)
    secret_key = secret_key.to_s.strip
    raise StripeGateway::Error, I18n.t("admin.stripe_connections.wrong_key") unless secret_key.match?(/\A(sk|rk)_(test|live)_\w+\z/)

    gateway = StripeGateway.build(secret_key)
    name = gateway.account_name
    disconnect_stripe!
    update!(stripe_secret_key: secret_key, stripe_account_name: name)
    register_stripe_webhook!(webhook_url)
  end

  # (Re)registers the webhook at url, e.g. after the shop moved to a new address.
  def register_stripe_webhook!(url)
    return unless stripe_connected? && self.class.public_url?(url)

    stripe.delete_webhook(stripe_webhook_id) if stripe_webhook_id
    id, secret = stripe.create_webhook(url)
    update!(stripe_webhook_id: id, stripe_webhook_url: url, stripe_webhook_secret: secret)
  end

  def disconnect_stripe!
    stripe.delete_webhook(stripe_webhook_id) if stripe_connected? && stripe_webhook_id
    update!(stripe_secret_key: nil, stripe_account_name: nil, stripe_webhook_id: nil, stripe_webhook_url: nil, stripe_webhook_secret: nil)
  end

  def stripe_test_mode?
    stripe_connected? && stripe.test_mode?
  end

  # The webhook secret, nil when unreadable (see stripe_key).
  def stripe_signing_secret
    stripe_webhook_secret
  rescue ActiveRecord::Encryption::Errors::Decryption
    nil
  end

  # Stripe can only call addresses on the internet, over https.
  def self.public_url?(url)
    uri = URI.parse(url.to_s)
    uri.scheme == "https" && uri.host.present? && !uri.host.match?(/(\Alocalhost|\.localhost|\.local|\.test)\z|\A(127\.|10\.|192\.168\.)/)
  rescue URI::InvalidURIError
    false
  end

  AGENT_ROLES = %w[ storefront merchant ].freeze

  # A new key for AI agents (the agent API, /agent/v1): "storefront" for shopping agents acting
  # for buyers, "merchant" for the owner's assistant. Only its digest is kept; the key is shown
  # once. A new key replaces the old one.
  def generate_agent_key!(role)
    key = "#{role == "merchant" ? "mk" : "sk"}_agent_#{SecureRandom.base58(40)}"
    update!("#{agent_role!(role)}_agent_key_digest" => self.class.agent_key_digest(key))
    key
  end

  def revoke_agent_key!(role)
    update!("#{agent_role!(role)}_agent_key_digest" => nil)
  end

  def agent_key?(role)
    public_send("#{agent_role!(role)}_agent_key_digest").present?
  end

  def agent_key_valid?(role, key)
    digest = public_send("#{agent_role!(role)}_agent_key_digest")
    digest.present? && key.present? && ActiveSupport::SecurityUtils.secure_compare(digest, self.class.agent_key_digest(key))
  end

  def self.agent_key_digest(key)
    OpenSSL::Digest::SHA256.hexdigest(key.to_s)
  end

  def policy(id)
    public_send(POLICIES.fetch(id)).presence
  end

  def published_policies
    POLICIES.keys.select { |id| policy(id) }
  end

  private
    def agent_role!(role)
      AGENT_ROLES.include?(role.to_s) ? role.to_s : raise(ArgumentError, "Unknown agent role #{role.inspect}")
    end

    # The key, nil when it can't be decrypted (the app's SECRET_KEY_BASE changed): the owner
    # connects Stripe again.
    def stripe_key
      stripe_secret_key
    rescue ActiveRecord::Encryption::Errors::Decryption
      nil
    end

    def countries_are_known
      unknown = ship_to_countries - Country.codes
      errors.add(:ship_to_countries, :unknown, codes: unknown.join(", ")) if unknown.any?
    end

  Shop.extend_model(self)
end
