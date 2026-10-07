# What the agent cost, one row per turn, charged to the account that owns the app. Kept
# when the app is deleted, so deleting apps doesn't make room in the month's budget.
class Usage < ApplicationRecord
  belongs_to :user
  belongs_to :project, optional: true

  scope :this_month, -> { where(created_at: Time.current.beginning_of_month..) }
end
