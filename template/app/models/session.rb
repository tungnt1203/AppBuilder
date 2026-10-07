# A signed-in owner or staff member (User) in /admin. Customers have CustomerSession.
class Session < ApplicationRecord
  belongs_to :user
end
