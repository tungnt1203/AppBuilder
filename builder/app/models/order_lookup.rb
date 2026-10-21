# A buyer finding their orders at a shop by their email, without an account: the shop emails them
# a link that lists those orders. The link's token holds the shop, the email and whether it's the
# preview's (test orders) or the published shop's, encrypted (so an email never shows in an
# address) and signed, for a day. Shops never see each other's buyers: the same email at another
# shop finds nothing here.
class OrderLookup
  EXPIRES_IN = 1.day
  LIMIT = 20

  attr_reader :shop, :email

  def self.encryptor
    @encryptor ||= ActiveSupport::MessageEncryptor.new(Rails.application.key_generator.generate_key("order lookups", 32), url_safe: true)
  end

  # The lookup a token stands for, in the current shop; nil when it's expired, forged or another shop's.
  def self.from_token(token, shop: ActsAsTenant.current_tenant)
    shop_id, email, test = encryptor.decrypt_and_verify(token.to_s, purpose: :order_lookup)
    new(email, test:, shop:) if shop_id == shop.id
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError, TypeError
    nil
  end

  def initialize(email, test:, shop: ActsAsTenant.current_tenant)
    @email, @test, @shop = email.to_s.strip.downcase, test, shop
  end

  def valid?
    email.match?(ApplicationRecord::EMAIL_FORMAT) && email.length <= 254
  end

  def test? = @test

  # The buyer's orders at the shop, newest first.
  def orders
    Order.where(email:, test: test?).newest_first.limit(LIMIT)
  end

  def token
    self.class.encryptor.encrypt_and_sign([ shop.id, email, test? ], purpose: :order_lookup, expires_in: EXPIRES_IN)
  end

  # Emails the link when the email has orders here, and does nothing otherwise: the caller can't
  # tell which, so nobody learns who bought from the shop.
  def deliver_later
    OrderMailer.lookup(shop, email, token).deliver_later if valid? && orders.exists?
  end
end
