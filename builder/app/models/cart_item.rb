class CartItem < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :cart, touch: true
  belongs_to :variant

  validates :quantity, numericality: { only_integer: true, in: 1..Cart::MAX_QUANTITY }
  validates :variant_id, uniqueness: { scope: %i[ shop_id cart_id properties ] }

  before_validation { self.properties = properties.to_h.stringify_keys.sort.to_h }

  delegate :product, to: :variant

  def total_cents
    variant.price_cents * quantity
  end
end
