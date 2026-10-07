class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :projects, foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_error

  # owner: the first account; cannot be removed or demoted.
  # admin: manages accounts and can open every app.
  # member: everyone else, who sees only their own apps.
  enum :role, %w[ member admin owner ].index_by(&:itself), default: "member"

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :owner_role_is_permanent, on: :update

  before_create :become_owner_of_new_builder
  after_create_commit :adopt_ownerless_projects, if: :owner?
  before_destroy :prevent_owner_removal

  scope :ordered, -> { order(:name) }

  def administrator?
    admin? || owner?
  end

  # The owner's role stays; nobody changes their own.
  def role_changeable_by?(user)
    user.administrator? && !owner? && user != self
  end

  def removable_by?(user)
    user.administrator? && !owner? && user != self && projects.none?
  end

  # The apps this account may open: its own, or every app for administrators.
  def accessible_projects
    administrator? ? Project.all : projects
  end

  private
    def become_owner_of_new_builder
      self.role = :owner unless User.exists?
    end

    def adopt_ownerless_projects
      Project.where(owner_id: nil).update_all(owner_id: id)
    end

    def owner_role_is_permanent
      errors.add(:role, "can't be changed for the owner") if role_changed? && role_was == "owner"
    end

    def prevent_owner_removal
      if role_in_database == "owner"
        errors.add(:base, "The owner can't be removed")
        throw :abort
      end
    end
end
