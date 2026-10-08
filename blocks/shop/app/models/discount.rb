# A discount code buyers enter in the cart: a percentage off, an amount off, or free shipping,
# optionally from a minimum order, between two dates, for a limited number of orders.
# The order keeps the code and the amount it took off (Order#discount_cents).
class Discount < ApplicationRecord
  include MoneyAttributes

  KINDS = %w[ percentage fixed_amount free_shipping ].freeze

  has_many :orders, dependent: :nullify

  enum :kind, KINDS.index_by(&:itself), default: "percentage"

  money_attribute :amount_off, :minimum_subtotal

  validates :code, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 40 },
    format: { with: /\A[A-Z0-9_-]+\z/, message: :letters_and_numbers }
  validates :percent_off, numericality: { only_integer: true, in: 1..100 }, if: :percentage?
  validates :amount_off_cents, numericality: { only_integer: true, greater_than: 0 }, if: :fixed_amount?
  validates :minimum_subtotal_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :usage_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :ends_after_start

  normalizes :code, with: ->(code) { code.to_s.strip.upcase.gsub(/\s+/, "") }

  scope :ordered, -> { order(created_at: :desc) }

  def self.find_by_code(code)
    find_by(code: normalize_value_for(:code, code)) if code.present?
  end

  # Why the code can't be used on this subtotal now (an error key), or nil when it can.
  def problem_with(subtotal_cents, now = Time.current)
    if !active? || (ends_at && now >= ends_at) then :expired
    elsif starts_at && now < starts_at then :not_started
    elsif usage_limit && times_used >= usage_limit then :used_up
    elsif minimum_subtotal_cents && subtotal_cents < minimum_subtotal_cents then :below_minimum
    end
  end

  # What it takes off the items (never more than they cost); free shipping takes off nothing here.
  def amount_for(subtotal_cents)
    cents = case kind
    when "percentage" then (subtotal_cents * percent_off / 100.0).round
    when "fixed_amount" then amount_off_cents
    else 0
    end
    cents.clamp(0, subtotal_cents)
  end

  # Counts one use, unless the limit was reached meanwhile. Returns false then.
  def redeem!
    scope = self.class.where(id:)
    scope = scope.where(times_used: ...usage_limit) if usage_limit
    scope.update_all("times_used = times_used + 1").positive?
  end

  def release!
    self.class.where(id:).where(times_used: 1..).update_all("times_used = times_used - 1")
  end

  private
    def ends_after_start
      errors.add(:ends_at, :before_start) if starts_at && ends_at && ends_at <= starts_at
    end

  Shop.extend_model(self)
end
