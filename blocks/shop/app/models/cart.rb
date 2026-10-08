# A visitor's cart, found by a signed cookie (see the CurrentCart concern). Carts nobody has
# touched for a while are cleared by Cart::CleanupJob.
class Cart < ApplicationRecord
  MAX_QUANTITY = 99

  has_many :items, -> { order(:id) }, class_name: "CartItem", dependent: :delete_all

  scope :abandoned, -> { where(updated_at: ...30.days.ago) }

  def add(variant, quantity = 1)
    item = items.find_or_initialize_by(variant:)
    item.quantity = ((item.new_record? ? 0 : item.quantity) + quantity.to_i).clamp(1, MAX_QUANTITY)
    item.save!
    touch
    item
  end

  # Items whose variant can still be bought; the others are dropped at checkout.
  def buyable_items
    items.includes(variant: { product: { images_attachments: :blob } }).select { |item| item.variant.buyable? }
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

  Shop.extend_model(self)
end
