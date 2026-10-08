# A variant in a sale, with its prices from before the sale started.
class PromotionItem < ApplicationRecord
  belongs_to :promotion
  belongs_to :variant

  validates :variant_id, uniqueness: { scope: :promotion_id }
end
