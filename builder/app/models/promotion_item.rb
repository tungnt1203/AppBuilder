# A variant in a sale, with its prices from before the sale started.
class PromotionItem < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :promotion
  belongs_to :variant

  validates :variant_id, uniqueness: { scope: %i[ shop_id promotion_id ] }
end
