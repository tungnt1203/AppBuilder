# A line in an order's timeline: placed, paid, shipped, a note… and who did it (nil: the buyer
# or the app itself).
class OrderEvent < ApplicationRecord
  belongs_to :order
  belongs_to :user, optional: true

  validates :action, presence: true

  Shop.extend_model(self)
end
