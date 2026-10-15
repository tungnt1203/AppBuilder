# Someone who runs a shop: its owner (one or more, they manage everything and its people), an
# admin (everything but its people and its ownership), or staff (the daily work: orders, products).
class ShopMembership < ApplicationRecord
  ROLES = %w[ owner admin staff ].freeze

  belongs_to :shop
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :shop_id }

  def owner? = role == "owner"
  def administrator? = role.in?(%w[ owner admin ])
end
