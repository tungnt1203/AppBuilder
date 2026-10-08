# One line of an order, with the product's title, option values and price copied in at checkout.
class LineItem < ApplicationRecord
  belongs_to :order
  belongs_to :variant, optional: true

  validates :product_title, presence: true
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :quantity, numericality: { greater_than: 0, only_integer: true }

  def total_cents
    unit_price_cents * quantity
  end

  def product
    variant&.product
  end

  Shop.extend_model(self)
end
