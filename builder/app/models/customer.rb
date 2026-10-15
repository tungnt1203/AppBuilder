# A buyer's account in one shop (optional: buyers always check out without one). Accounts are
# the shop's own: the same email at another shop is another account. Never signs in to the
# platform's admin (that's User).
class Customer < ApplicationRecord
  acts_as_tenant :shop

  has_secure_password
  has_many :orders, dependent: :nullify

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: { scope: :shop_id }, format: { with: EMAIL_FORMAT }
  validates :password, length: { minimum: 8 }, allow_nil: true

  scope :ordered, -> { order(:name) }
end
