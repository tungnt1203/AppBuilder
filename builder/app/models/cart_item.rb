class CartItem < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :cart, touch: true
  belongs_to :variant

  validates :quantity, numericality: { only_integer: true, in: 1..Cart::MAX_QUANTITY }
  validates :variant_id, uniqueness: { scope: %i[ shop_id cart_id ] }

  delegate :product, to: :variant

  def total_cents
    variant.price_cents * quantity
  end
end
