class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  # owner: created on first run, cannot be removed or demoted.
  # admin: also manages the staff accounts in /admin/users.
  # staff: everyone else who works in /admin.
  enum :role, %w[ staff admin owner ].index_by(&:itself), default: "staff"

  # Invitation links stop working once the invited user sets a password.
  generates_token_for :invitation, expires_in: 7.days do
    password_salt.last(10)
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: EMAIL_FORMAT }
  validate :owner_role_is_permanent, on: :update

  before_destroy :prevent_owner_removal

  scope :ordered, -> { order(:name) }

  def self.invite(attributes)
    create(attributes.merge(password: SecureRandom.base58(32)))
  end

  def administrator?
    admin? || owner?
  end

  def role_name
    I18n.t(role, scope: "users.roles")
  end

  private
    def owner_role_is_permanent
      errors.add(:role, :owner_permanent) if role_changed? && role_was == "owner"
    end

    def prevent_owner_removal
      if role_in_database == "owner"
        errors.add(:base, :owner_permanent)
        throw :abort
      end
    end
end
