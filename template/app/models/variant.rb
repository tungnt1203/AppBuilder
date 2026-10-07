# One buyable version of a product (Black / M), with its own price and SKU.
class Variant < ApplicationRecord
  include MoneyAttributes

  belongs_to :product, inverse_of: :variants, touch: true
  has_many :cart_items, dependent: :delete_all
  has_many :line_items, dependent: :nullify

  money_attribute :price, :compare_at_price

  validates :price_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :compare_at_price_cents, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :sku, length: { maximum: 100 }
  validate :one_variant_per_combination

  normalizes :sku, with: ->(sku) { sku.strip.presence }

  def option_values
    [ option1, option2, option3 ].compact
  end

  # "Black / M", or nil for a product without options.
  def title
    option_values.join(" / ").presence
  end

  def matches?(selected)
    selected = Array(selected).map(&:to_s)
    option_values == selected.first(option_values.size) && selected.size == option_values.size
  end

  def on_sale?
    compare_at_price_cents.to_i > price_cents
  end

  def buyable?
    available? && product.active?
  end

  private
    def one_variant_per_combination
      duplicate = Variant.where(product_id: product_id, option1: option1, option2: option2, option3: option3).where.not(id: id)
      errors.add(:base, :taken) if duplicate.exists?
    end
end
