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
  has_one :store, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  has_many :platform_requests, dependent: :destroy

  normalizes :subdomain, with: ->(subdomain) { subdomain.strip.downcase }
  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, length: { maximum: 100 }
  validates :subdomain, presence: true, uniqueness: true, length: { maximum: 63 },
    format: { with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/ }, exclusion: { in: RESERVED_SUBDOMAINS }
  validates :currency, inclusion: { in: Store::CURRENCIES.keys }
  validates :status, inclusion: { in: STATUSES }
  validate :time_zone_exists

  before_validation :assign_uid, on: :create

  # Runs the block inside each shop in turn, for work every shop needs (recurring jobs).
  def self.each_in_turn(&block)
    ActsAsTenant.without_tenant { Shop.order(:id).to_a }.each { |shop| ActsAsTenant.with_tenant(shop, &block) }
  end

  # A new shop with its first owner.
  def self.open!(owner:, **attributes)
    transaction do
      create!(**attributes).tap { |shop| shop.memberships.create!(user: owner, role: "owner") }
    end
  end

  # An address on the shop's storefront, where it's published at its subdomain.
  def storefront_url(path = "/")
    domain = Rails.configuration.x.publish_domain
    scheme = domain == "localhost" ? "http" : "https"
    "#{scheme}://#{subdomain}.#{domain}#{path}"
  end

  # /admin/shops/<subdomain>/…
  def to_param = subdomain_was.presence || subdomain

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
