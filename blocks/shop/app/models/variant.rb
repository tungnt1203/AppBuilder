# One buyable version of a product (Black / M), with its own price and SKU.
class Variant < ApplicationRecord
  include MoneyAttributes

  belongs_to :product, inverse_of: :variants, touch: true
  has_many :cart_items, dependent: :delete_all
  has_many :line_items, dependent: :nullify
  has_many :promotion_items, dependent: :destroy

  money_attribute :price, :compare_at_price, :cost

  validates :price_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
  validates :inventory_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
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

  # Variants that don't track inventory (made to order, print on demand) never run out.
  def in_stock?
    !track_inventory? || inventory_quantity.positive?
  end

  # How many a buyer can have: the stock when it's tracked, otherwise any number.
  def purchasable_quantity
    track_inventory? ? inventory_quantity : Float::INFINITY
  end

  def low_stock?(threshold = Store.current.low_stock_threshold)
    track_inventory? && inventory_quantity <= threshold
  end

  def sellable?
    available? && in_stock?
  end

  def buyable?
    sellable? && product.active?
  end

  # Takes quantity out of stock if there's that much, in one statement so two checkouts can't
  # both take the last one. Returns false when there isn't enough. Untracked variants: true.
  def take_stock(quantity)
    return true unless track_inventory?

    taken = self.class.where(id:).where(inventory_quantity: quantity..).update_all([ "inventory_quantity = inventory_quantity - ?", quantity ])
    reload if taken.positive?
    taken.positive?
  end

  def return_stock(quantity)
    self.class.where(id:, track_inventory: true).update_all([ "inventory_quantity = inventory_quantity + ?", quantity ])
  end

  private
    def one_variant_per_combination
      duplicate = Variant.where(product_id: product_id, option1: option1, option2: option2, option3: option3).where.not(id: id)
      errors.add(:base, :taken) if duplicate.exists?
    end

  Shop.extend_model(self)
end
