# An order placed at checkout. Prices, titles and the address are copied in, so the order stays
# as it was bought even when products change later. The buyer reaches it by its token
# (order_path(order)); staff by its number in /admin.
#
# Status moves forward with the methods below, each recorded as an event in the order's timeline:
#   pending (placed, waiting for payment) → paid → in_production → shipped → delivered
#   cancelled from pending or paid, refunded from any paid status.
#
# Cancelling gives the buyer's card payment back and puts the items back in stock. Refunding puts
# them back while the order hasn't shipped; once it has, staff put them back
# (#return_to_stock!) only when they come back. refunded_cents is what went back to the buyer,
# a part of the total when refunded partly in Stripe's dashboard.
#
# Payment is "manual" (the buyer follows the shop's payment instructions and staff mark the order
# paid) or "stripe" (the buyer pays by card in the storefront: #card_payment!, then
# #confirm_card_payment!). A card
# order stays pending until Stripe says it's paid; until then it's a checkout the buyer hasn't
# finished, kept out of the orders that need action and cancelled after a day.
class Order < ApplicationRecord
  acts_as_tenant :shop

  include MoneyAttributes

  STATUSES = %w[ pending paid in_production shipped delivered cancelled refunded ].freeze
  PAYMENT_METHODS = %w[ manual stripe ].freeze
  UNPAID_CARD_EXPIRY = StripeGateway::CHECKOUT_EXPIRY
  # How long a card order the buyer didn't pay stays open for them to finish after the reminder.
  UNPAID_CARD_RECOVERY = 1.day
  FIRST_NUMBER = 1001

  belongs_to :customer, optional: true
  belongs_to :discount, optional: true
  has_many :line_items, -> { order(:id) }, dependent: :destroy
  has_many :events, -> { order(:created_at, :id) }, class_name: "OrderEvent", dependent: :destroy
  has_many :product_reviews, dependent: :destroy

  has_secure_token :token, length: 32
  enum :status, STATUSES.index_by(&:itself), default: "pending"

  money_attribute :subtotal, :shipping, :tax, :total

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
  scope :counted_in_sales, -> { real.where(status: %w[ paid in_production shipped delivered ]) }
  # Orders placed in a storefront's preview are tests: never printed, reported or counted.
  scope :real, -> { where(test: false) }
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
      where("orders.email ILIKE :like OR orders.shipping_name ILIKE :like", like:)
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

  # What the shop keeps once Printify is paid: the total, less tax, refunds and Printify's bill
  # (payment fees aside). nil until Printify has billed it.
  def margin_cents
    total_cents - tax_cents - refunded_cents - fulfillment_cost_cents if fulfillment_cost_cents
  end

  # Staff mark manual payments; card payments are confirmed by Stripe.
  def can_mark_paid? = pending? && !card?
  def can_start_production? = paid?
  def can_ship? = paid? || in_production?
  def can_mark_delivered? = shipped?
  def can_cancel? = pending? || paid?
  def can_refund? = paid_status?
  def can_return_to_stock? = refunded? && restocked_at.nil? && line_items.any? { |item| item.variant&.track_inventory? }

  # A card order already paid, whose money goes back to the buyer when it's cancelled.
  def card_payment_taken? = card? && paid? && payment_reference.present?

  def mark_paid!(by: nil, reference: nil)
    transition! :paid, from: :can_mark_paid?, by:, paid_at: Time.current, payment_reference: reference.presence || payment_reference
    fulfill_later
  end

  def start_production!(by: nil, message: nil)
    transition! :in_production, from: :can_start_production?, by:, message:
  end

  # Paid orders with products from Printify go there to be printed (Printify::Fulfillment).
  def fulfill_later
    Order::FulfillJob.perform_later(self) if Store.current.printify_connected? && !test?
  end

  # A placed order goes to Meta's Conversions API too (Meta::Purchase): manual orders when placed,
  # card orders once paid, like the pixel's Purchase.
  def report_purchase_later
    Order::ReportPurchaseJob.perform_later(self) if Store.current.meta_conversions? && !test?
  end

  # Buyers review what they bought once it's on its way (see ProductReview).
  def reviewable?
    shipped? || delivered?
  end

  # The order's products still on sale that the buyer hasn't reviewed yet.
  def reviewable_products
    return Product.none unless reviewable?

    Product.visible.where(id: line_items.joins(:variant).select("variants.product_id")).where.not(id: product_reviews.select(:product_id))
  end

  # The buyer's page for the order on the shop's storefront; path: "review" for its review page.
  def storefront_url(path = nil)
    shop.storefront_url([ "/orders/#{token}", path ].compact.join("/"))
  end

  def printify_url
    "https://printify.com/app/order/#{printify_order_id}" if printify_order_id.present?
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

  # Puts the items back in stock and gives the discount code its use back; a card payment
  # already taken goes back through Stripe first (raises StripeGateway::Error when Stripe
  # refuses). Tells the buyer unless notify: false.
  def cancel!(by: nil, reason: nil, notify: true)
    raise InvalidTransition, "#{name} can't be cancelled while #{status}" unless can_cancel?
    refunding = card_payment_taken?
    refund_in_stripe if refunding
    transaction do
      transition! :cancelled, from: :can_cancel?, by:, cancelled_at: Time.current, message: reason,
        **(refunding ? { refunded_at: Time.current, refunded_cents: total_cents } : {})
      restock
      discount&.release!
    end
    Printify::Fulfillment.new(self).cancel!
    OrderMailer.cancelled(self).deliver_later if notify
  end

  # A card order's money goes back through Stripe first (pass stripe: false when Stripe already
  # refunded it). Raises StripeGateway::Error when Stripe refuses. Items not shipped yet go back
  # in stock.
  def refund!(by: nil, reason: nil, stripe: card?)
    raise InvalidTransition, "#{name} can't be refunded while #{status}" unless can_refund?
    refund_in_stripe if stripe
    transaction do
      shipped = shipped_at.present?
      transition! :refunded, from: :can_refund?, by:, refunded_at: Time.current, refunded_cents: total_cents, message: reason
      restock unless shipped
    end
    Printify::Fulfillment.new(self).cancel!
    OrderMailer.refunded(self).deliver_later
  end

  # Puts a refunded order's items back in stock once they came back to the shop.
  def return_to_stock!(by: nil)
    transaction do
      lock!
      raise InvalidTransition, "#{name}'s items can't go back in stock" unless can_return_to_stock?
      restock
      record "restocked", by:
    end
  end

  # A refund of part of the order made in Stripe's dashboard (refunded: Stripe's total refunded
  # so far, in the shop's hundredths). The order stays as it was; the timeline shows the amount.
  def record_partial_refund!(refunded)
    return if refunded <= refunded_cents || refunded >= total_cents

    transaction do
      lock!
      update!(refunded_cents: refunded)
      record "partially_refunded", message: ApplicationController.helpers.money(refunded, currency)
    end
  end

  # The card payment the buyer confirms in the storefront (Stripe's Payment Element): the order's
  # PaymentIntent, made the first time with Stripe Tax's tax added when the store has it on, the
  # same one after. Returns { id:, client_secret: }. Raises InvalidTransition unless the order
  # waits for a card payment, StripeGateway::Error when Stripe refuses.
  def card_payment!(gateway = Store.current.stripe)
    raise InvalidTransition, "#{name} doesn't wait for a card payment" unless card? && pending?
    raise StripeGateway::Error, I18n.t("orders.stripe_not_connected") unless gateway

    with_lock do
      next gateway.payment_intent(stripe_payment_intent_id).merge(id: stripe_payment_intent_id) if stripe_payment_intent_id

      if Store.current.stripe_tax?
        tax = gateway.tax_calculation(self)
        update!(stripe_tax_calculation_id: tax[:id], tax_cents: tax[:tax_cents], total_cents: total_cents - tax_cents + tax[:tax_cents])
      end
      gateway.create_payment_intent(self, tax_calculation: stripe_tax_calculation_id).tap do |intent|
        update!(stripe_payment_intent_id: intent[:id])
      end
    end
  end

  # Called when Stripe says the order's PaymentIntent succeeded (the buyer coming back to the
  # order page, or the webhook; whichever is first). Marks it paid, empties the cart it came from,
  # records its tax with Stripe Tax and sends the emails that a manual order sends when it's
  # placed. Safe to call again.
  def confirm_card_payment!(payment_intent: stripe_payment_intent_id, gateway: Store.current.stripe)
    return false unless card? && pending?

    transition! :paid, from: :pending?, by: nil, paid_at: Time.current, payment_reference: payment_intent, message: "Stripe"
    if cart_id
      CartItem.where(cart_id:).delete_all
      Cart.where(id: cart_id).update_all(discount_code: nil)
    end
    record_tax(gateway)
    OrderMailer.confirmation(self).deliver_later
    Admin::OrderMailer.placed(self).deliver_later
    report_purchase_later
    fulfill_later
    true
  rescue InvalidTransition
    false # the other confirmation got there first
  end

  # Asks Stripe whether the buyer paid this card order (they may just have, and the webhook
  # can't reach a shop without a public address, like its preview) and confirms it if so.
  def sync_card_payment!(gateway = Store.current.stripe)
    return unless card? && pending? && stripe_payment_intent_id && gateway

    result = gateway.payment_intent(stripe_payment_intent_id)
    confirm_card_payment!(gateway:) if result[:paid]
    result
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

    def record_tax(gateway)
      gateway&.record_tax(stripe_tax_calculation_id, name) if stripe_tax_calculation_id
    rescue StripeGateway::Error => error
      Rails.logger.warn "Couldn't record #{name}'s tax with Stripe Tax: #{error.message}"
    end

    def refund_in_stripe
      gateway = Store.current.stripe or raise StripeGateway::Error, I18n.t("orders.stripe_not_connected")
      gateway.refund(payment_reference)
    end

    def restock
      return if restocked_at

      line_items.each { |item| item.variant&.return_stock(item.quantity) }
      update!(restocked_at: Time.current)
    end

    def assign_number
      self.number ||= [ Order.maximum(:number).to_i + 1, FIRST_NUMBER ].max
    end
end
