# Someone who buys or uses the app from the customers' site: signs up on their own, signs in at
# /session/new and sees their account at /account. Never signs in to /admin (that's User).
class Customer < ApplicationRecord
  has_secure_password
  has_many :sessions, class_name: "CustomerSession", dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: EMAIL_FORMAT }
  validates :password, length: { minimum: 8 }, allow_nil: true

  scope :ordered, -> { order(:name) }
end
