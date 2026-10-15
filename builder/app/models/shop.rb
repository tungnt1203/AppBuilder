# A shop of the platform: a storefront at its subdomain, and its own data. Every table of a
# shop's data has a shop_id and its model `acts_as_tenant :shop`, so queries only ever see the
# current shop's rows (ActsAsTenant.current_tenant, set from the signed-in admin's pick or the
# storefront's API key). Owners and staff reach it through memberships; storefronts through API
# keys; the builder's project is its storefront's code.
class Shop < ApplicationRecord
  STATUSES = %w[ draft live ].freeze
  RESERVED_SUBDOMAINS = %w[ www admin api app platform builder mail ].freeze

  has_many :memberships, class_name: "ShopMembership", dependent: :destroy
  has_many :users, through: :memberships
  has_many :api_keys, class_name: "ShopApiKey", dependent: :destroy
  has_one :project, dependent: :nullify

  normalizes :subdomain, with: ->(subdomain) { subdomain.strip.downcase }
  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, length: { maximum: 100 }
  validates :subdomain, presence: true, uniqueness: true, length: { maximum: 63 },
    format: { with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/ }, exclusion: { in: RESERVED_SUBDOMAINS }
  validates :currency, inclusion: { in: %w[ USD EUR GBP CAD AUD VND JPY ] }
  validates :status, inclusion: { in: STATUSES }
  validate :time_zone_exists

  before_validation :assign_uid, on: :create

  # A new shop with its first owner.
  def self.open!(owner:, **attributes)
    transaction do
      create!(**attributes).tap { |shop| shop.memberships.create!(user: owner, role: "owner") }
    end
  end

  def role_of(user)
    memberships.find_by(user:)&.role
  end

  private
    def assign_uid
      self.uid ||= loop do
        candidate = SecureRandom.alphanumeric(6).downcase
        break candidate unless Shop.exists?(uid: candidate)
      end
    end

    def time_zone_exists
      errors.add(:time_zone, :inclusion) unless ActiveSupport::TimeZone[time_zone.to_s]
    end
end
