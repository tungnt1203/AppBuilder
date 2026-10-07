class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :projects, foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_error
  has_many :usages, dependent: :delete_all

  # Less than this left and a turn can't do much, so none starts.
  MIN_TURN_USD = 0.25

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

  # Members may have a few apps each (config.x.apps_per_account); deleting one makes room.
  def app_limit
    Rails.configuration.x.apps_per_account unless administrator?
  end

  def app_limit_reached?
    app_limit.present? && projects.count >= app_limit
  end

  # Members' apps may spend up to config.x.monthly_budget_usd on the agent each month.
  def monthly_budget
    Rails.configuration.x.monthly_budget_usd unless administrator?
  end

  def spent_this_month
    usages.this_month.sum(:cost_usd).to_f
  end

  def budget_left
    [ monthly_budget - spent_this_month, 0 ].max if monthly_budget
  end

  def over_budget?
    monthly_budget.present? && budget_left < MIN_TURN_USD
  end

  def budget_message
    "This month's budget for the agent is used up ($%.2f of $%.2f). It starts again on %s." %
      [ spent_this_month, monthly_budget, Time.current.next_month.beginning_of_month.to_date.to_fs(:long) ]
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
