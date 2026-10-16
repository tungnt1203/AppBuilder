# One line of an order, with the product's title, option values and price copied in at checkout.
class LineItem < ApplicationRecord
  acts_as_tenant :shop

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

  # "Name on the shirt: Ada", using the product's labels while it still has them.
  def property_lines
    return [] if properties.blank?

    labels = product&.buyer_inputs.to_a.to_h { |field| [ field["key"], field["label"] ] }
    properties.map { |key, value| "#{labels[key] || key}: #{value}" }
  end
end
