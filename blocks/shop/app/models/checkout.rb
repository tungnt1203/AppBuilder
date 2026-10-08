# Turns a cart into an order: checks the buyer's details and where it ships, copies each item's
# price and titles and adds shipping, in one transaction. Prices always come from the database,
# never from the form. A manual-payment order empties the cart and is confirmed by email right
# away; a card order keeps both until Stripe confirms the payment (Order#confirm_card_payment!),
# so a buyer who backs out of Stripe still has their cart.
class Checkout
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :phone, :string
  attribute :shipping_name, :string
  attribute :shipping_address1, :string
  attribute :shipping_address2, :string
  attribute :shipping_city, :string
  attribute :shipping_region, :string
  attribute :shipping_postal_code, :string
  attribute :shipping_country, :string
  attribute :note, :string
  attribute :payment_method, :string

  attr_reader :cart, :order
  attr_accessor :customer

  validates :email, presence: true, format: { with: ApplicationRecord::EMAIL_FORMAT }
  validates :shipping_name, :shipping_address1, :shipping_city, :shipping_country, presence: true
  validate :cart_has_items
  validate :ships_to_country
  validates :payment_method, inclusion: { in: ->(checkout) { checkout.payment_methods } }

  def initialize(cart:, store: Store.current, **attributes)
    @cart, @store = cart, store
    super(**attributes)
    self.payment_method = payment_methods.first unless payment_methods.include?(payment_method)
  end

  def payment_methods
    @store.payment_methods
  end

  def self.human_attribute_name(attribute, options = {})
    Order.human_attribute_name(attribute, options)
  end

  def items
    @items ||= cart.buyable_items
  end

  def subtotal_cents
    items.sum(&:total_cents)
  end

  def shipping_cents
    @store.shipping_cents_for(item_count: items.sum(&:quantity), subtotal_cents:)
  end

  def total_cents
    subtotal_cents + shipping_cents
  end

  # Places the order. Returns it, or nil with errors on the checkout (or on the order).
  def place
    return unless valid?

    @order = Order.new(order_attributes)
    items.each do |item|
      @order.line_items.build(variant: item.variant, product_title: item.product.title,
        variant_title: item.variant.title, sku: item.variant.sku,
        unit_price_cents: item.variant.price_cents, quantity: item.quantity)
    end

    with_number_retry do
      ActiveRecord::Base.transaction do
        @order.save!
        @order.record :placed
        cart.items.delete_all unless @order.card?
      end
    end
    unless @order.card?
      OrderMailer.confirmation(@order).deliver_later
      Admin::OrderMailer.placed(@order).deliver_later
    end
    @order
  rescue ActiveRecord::RecordInvalid
    @order.errors.each { |error| errors.add(error.attribute, error.message) unless error.attribute.to_s.start_with?("line_items") }
    nil
  end

  private
    # Two orders placed at the same moment can pick the same number; the second tries the next.
    def with_number_retry(attempts = 3)
      yield
    rescue ActiveRecord::RecordNotUnique
      @order.number = nil
      retry if (attempts -= 1).positive?
      raise
    end

    def order_attributes
      attributes.symbolize_keys.merge(customer:, currency: @store.currency,
        subtotal_cents:, shipping_cents:, total_cents:, cart_id: cart.id)
    end

    def cart_has_items
      errors.add(:base, :empty_cart) if items.empty?
    end

    def ships_to_country
      return if shipping_country.blank?
      errors.add(:shipping_country, :not_shipped_to) unless Country.codes.include?(shipping_country) && @store.ships_to?(shipping_country)
    end

  Shop.extend_model(self)
end
