# A group of products on the site: "New in", "Cat lovers", "Mugs".
class Collection < ApplicationRecord
  include Sluggable

  has_many :collection_products, -> { order(:position, :id) }, dependent: :destroy
  has_many :products, through: :collection_products

  validates :title, presence: true, length: { maximum: 200 }
  normalizes :title, with: ->(title) { title.squish }

  scope :ordered, -> { order(:position, :title) }

  # Puts exactly these products in the collection, in this order.
  def arrange_products(ids)
    ids = Array(ids).compact_blank.map(&:to_i).uniq & Product.where(id: ids).ids
    transaction do
      collection_products.where.not(product_id: ids).delete_all
      ids.each_with_index { |product_id, position| collection_products.find_or_initialize_by(product_id:).update!(position:) }
    end
    collection_products.reset
  end
end
