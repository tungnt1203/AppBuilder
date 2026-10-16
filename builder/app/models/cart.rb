# A buyer's cart in a shop, which the storefront keeps by its token (the Storefront API's carts).
# Carts nobody has touched for a while are cleared by Cart::CleanupJob.
class Cart < ApplicationRecord
  acts_as_tenant :shop

  MAX_QUANTITY = 99

  has_many :items, -> { order(:id) }, class_name: "CartItem", dependent: :delete_all
  has_secure_token :token, length: 32

  scope :abandoned, -> { where(updated_at: ...30.days.ago) }

  # Adds up to what's in stock: a line never asks for more than the variant has. The same variant
  # with different text the buyer typed (properties) is its own line.
  def add(variant, quantity = 1, properties: {})
    properties = properties.to_h.stringify_keys.sort.to_h
    item = items.find_or_initialize_by(variant:, properties:)
    item.quantity = ((item.new_record? ? 0 : item.quantity) + quantity.to_i).clamp(1, [ MAX_QUANTITY, variant.purchasable_quantity ].min)
    item.save!
    touch
    item
  end

  # Items whose variant can still be bought; the others are dropped at checkout.
  def buyable_items
    items.includes(variant: { product: { images_attachments: :blob } }).select { |item| item.variant.buyable? }
  end

  # Sets a line's quantity, within what's in stock; zero removes it.
  def update_quantity(item, quantity)
    quantity = quantity.to_i.clamp(0, [ MAX_QUANTITY, item.variant.purchasable_quantity ].min)
    quantity.positive? ? item.update!(quantity:) : item.destroy!
    touch
  end

  # The discount code the buyer entered, when it can be used on this cart now.
  def discount
    code = Discount.find_by_code(discount_code)
    code if code && code.problem_with(subtotal_cents).nil?
  end

  # Keeps the code when it can be used; returns the reason it can't otherwise (an error key).
  def apply_discount_code(code)
    discount = Discount.find_by_code(code)
    problem = discount ? discount.problem_with(subtotal_cents) : :unknown
    update!(discount_code: discount.code) unless problem
    problem
  end

  def remove_discount_code
    update!(discount_code: nil)
  end

  def item_count
    items.sum(:quantity)
  end

  def subtotal_cents
    buyable_items.sum(&:total_cents)
  end

  def empty?
    buyable_items.empty?
  end
end
