# An order placed at checkout. Prices, titles and the address are copied in, so the order stays
# as it was bought even when products change later. The buyer reaches it by its token
# (order_path(order)); staff by its number in /admin.
#
# Status moves forward with the methods below, each recorded as an event in the order's timeline:
#   pending (placed, waiting for payment) → paid → in_production → shipped → delivered
#   cancelled from pending or paid, refunded from any paid status.
#
# Payment is "manual" (the buyer follows the shop's payment instructions and staff mark the order
# paid) or "stripe" (the buyer pays by card on Stripe Checkout; see #confirm_card_payment!). A card
# order stays pending until Stripe says it's paid; until then it's a checkout the buyer hasn't
# finished, kept out of the orders that need action and cancelled after a day.
class Order < ApplicationRecord
  include MoneyAttributes

  STATUSES = %w[ pending paid in_production shipped delivered cancelled refunded ].freeze
  PAYMENT_METHODS = %w[ manual stripe ].freeze
  UNPAID_CARD_EXPIRY = 1.day
  FIRST_NUMBER = 1001

  belongs_to :customer, optional: true
  has_many :line_items, -> { order(:id) }, dependent: :destroy
  has_many :events, -> { order(:created_at, :id) }, class_name: "OrderEvent", dependent: :destroy

  has_secure_token :token, length: 32
  enum :status, STATUSES.index_by(&:itself), default: "pending"

  money_attribute :subtotal, :shipping, :total

  validates :email, presence: true, format: { with: EMAIL_FORMAT }, length: { maximum: 254 }
  validates :shipping_name, :shipping_address1, :shipping_city, :shipping_country, presence: true
  validates :shipping_name, :shipping_address1, :shipping_address2, :shipping_city, :shipping_region,
    :shipping_postal_code, :phone, length: { maximum: 200 }
  validates :note, :staff_note, length: { maximum: 2000 }
  validates :shipping_country, inclusion: { in: ->(_) { Country.codes } }
  validates :currency, inclusion: { in: Store::CURRENCIES.keys }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }
  validates :tracking_url, format: { with: %r{\Ahttps?://[^\s]+\z}i }, allow_blank: true

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :shipping_country, with: ->(code) { code.strip.upcase }

  before_create :assign_number

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :placed_since, ->(time) { where(created_at: time..) }
  scope :counted_in_sales, -> { where(status: %w[ paid in_production shipped delivered ]) }
  scope :needs_action, -> { where(status: %w[ paid in_production ]).or(awaiting_payment) }
  # Pending orders someone has to act on: manual payments the shop is waiting for.
  scope :awaiting_payment, -> { where(status: "pending", payment_method: "manual") }
  scope :unpaid_card, -> { where(status: "pending", payment_method: "stripe") }
  scope :search, ->(query) {
    query = query.to_s.strip.delete_prefix("#")
    if query.match?(/\A\d+\z/)
      where(number: query.to_i)
    elsif query.present?
      like = "%#{sanitize_sql_like(query)}%"
      where("orders.email LIKE :like OR orders.shipping_name LIKE :like", like:)
    end
  }

  def to_param
    token
  end

  def name
    "##{number}"
  end

  def item_count
    line_items.sum(&:quantity)
  end

  def shipping_address_lines
    [ shipping_name, shipping_address1, shipping_address2,
      [ shipping_city, shipping_region, shipping_postal_code ].compact_blank.join(", "),
      Country.name_for(shipping_country) ].compact_blank
  end

  def paid_status?
    paid? || in_production? || shipped? || delivered?
  end

  def card? = payment_method == "stripe"

  # Staff mark manual payments; card payments are confirmed by Stripe.
  def can_mark_paid? = pending? && !card?
  def can_start_production? = paid?
  def can_ship? = paid? || in_production?
  def can_mark_delivered? = shipped?
  def can_cancel? = pending? || paid?
  def can_refund? = paid_status?

  def mark_paid!(by: nil, reference: nil)
    transition! :paid, from: :can_mark_paid?, by:, paid_at: Time.current, payment_reference: reference.presence || payment_reference
  end

  def start_production!(by: nil)
    transition! :in_production, from: :can_start_production?, by:
  end

  def ship!(carrier:, tracking_number:, tracking_url: nil, by: nil)
    transition! :shipped, from: :can_ship?, by:, shipped_at: Time.current,
      carrier: carrier.to_s.strip.presence, tracking_number: tracking_number.to_s.strip.presence,
      tracking_url: tracking_url.to_s.strip.presence,
      message: [ carrier, tracking_number ].map(&:to_s).compact_blank.join(" ").presence
    OrderMailer.shipped(self).deliver_later
  end

  def mark_delivered!(by: nil)
    transition! :delivered, from: :can_mark_delivered?, by:, delivered_at: Time.current
  end

  def cancel!(by: nil, reason: nil)
    transition! :cancelled, from: :can_cancel?, by:, cancelled_at: Time.current, message: reason
  end

  # A card order's money goes back through Stripe first (pass stripe: false when Stripe already
  # refunded it). Raises StripeGateway::Error when Stripe refuses.
  def refund!(by: nil, reason: nil, stripe: card?)
    raise InvalidTransition, "#{name} can't be refunded while #{status}" unless can_refund?
    if stripe
      gateway = Store.current.stripe or raise StripeGateway::Error, I18n.t("orders.stripe_not_connected")
      gateway.refund(payment_reference)
    end
    transition! :refunded, from: :can_refund?, by:, refunded_at: Time.current, message: reason
  end

  # Called when Stripe says the order's Checkout Session is paid (the buyer coming back to the
  # order page, or the webhook; whichever is first). Marks it paid, empties the cart it came from
  # and sends the emails that a manual order sends when it's placed. Safe to call again.
  def confirm_card_payment!(payment_intent:)
    return false unless card? && pending?

    transition! :paid, from: :pending?, by: nil, paid_at: Time.current, payment_reference: payment_intent, message: "Stripe"
    CartItem.where(cart_id:).delete_all if cart_id
    OrderMailer.confirmation(self).deliver_later
    Admin::OrderMailer.placed(self).deliver_later
    true
  rescue InvalidTransition
    false # the other confirmation got there first
  end

  # Where staff see the payment in Stripe.
  def stripe_dashboard_url(test_mode: false)
    "https://dashboard.stripe.com/#{"test/" if test_mode}payments/#{payment_reference}" if card? && payment_reference.present?
  end

  def record(action, by: nil, message: nil)
    events.create!(action:, user: by, message: message.presence)
  end

  class InvalidTransition < StandardError; end

  private
    def transition!(status, from:, by:, message: nil, **attributes)
      transaction do
        lock!
        raise InvalidTransition, "#{name} can't become #{status} while #{self.status}" unless public_send(from)
        update!(status:, **attributes)
        record status, by:, message:
      end
    end

    def assign_number
      self.number ||= [ Order.maximum(:number).to_i + 1, FIRST_NUMBER ].max
    end

  Shop.extend_model(self)
end
