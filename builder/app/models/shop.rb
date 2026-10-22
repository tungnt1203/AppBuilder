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
  has_many :webhook_events, dependent: :delete_all

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

  # Deletes a shop that never took an order, with all its data and photos: a test shop, an
  # eval's. A shop with orders keeps everything (it raises): those are someone's sales.
  def purge!
    raise ActiveRecord::RecordNotDestroyed.new("#{name} has orders", self) if ActsAsTenant.without_tenant { Order.exists?(shop_id: id) }

    ActsAsTenant.without_tenant do
      transaction do
        [ Product, ThemeSetting, BuyerUpload ].each { |model| ActiveStorage::Attachment.where(record_type: model.name, record_id: model.where(shop_id: id).select(:id)).find_each(&:purge) }
        Project.where(shop_id: id).update_all(shop_id: nil)
        self.class.data_tables.each { |table| self.class.connection.delete("DELETE FROM #{table} WHERE shop_id = #{id.to_i}") }
        delete
      end
    end
  end

  # The tables of shops' data (the ones with a shop_id), each before the tables it refers to, so
  # deleting in this order never breaks a foreign key.
  def self.data_tables
    tables = connection.tables.select { |table| connection.column_exists?(table, :shop_id) } - [ "projects" ]
    refers_to = tables.index_with { |table| connection.foreign_keys(table).map(&:to_table) & tables }
    ordered = []
    until ordered.size == tables.size
      table = (tables - ordered).find { |candidate| (tables - ordered).none? { |other| other != candidate && refers_to[other].include?(candidate) } }
      ordered << (table or raise "Shops' tables refer to each other in a circle")
    end
    ordered
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
