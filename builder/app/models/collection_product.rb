class CollectionProduct < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :collection
  belongs_to :product

  validates :product_id, uniqueness: { scope: %i[ shop_id collection_id ] }
end
