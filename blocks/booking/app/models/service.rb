# Something a customer books: "Gel manicure", 45 minutes, $35. Done by the staff members who
# offer it.
class Service < ApplicationRecord
  include Sluggable, MoneyAttributes

  # Sluggable makes the address from the title.
  alias_attribute :title, :name

  has_many :service_staff_members, dependent: :destroy
  has_many :staff_members, -> { order(:position, :name) }, through: :service_staff_members
  has_many :appointments, dependent: :nullify

  enum :status, %w[ active hidden ].index_by(&:itself), default: "active"

  money_attribute :price

  validates :name, presence: true, length: { maximum: 200 }
  validates :duration_minutes, numericality: { only_integer: true, in: 5..(12 * 60) }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  normalizes :name, with: ->(name) { name.squish }

  scope :ordered, -> { order(:position, :name) }
  scope :bookable, -> { active.where(id: ServiceStaffMember.joins(:staff_member).merge(StaffMember.active).select(:service_id)) }

  def duration
    duration_minutes.minutes
  end

  def bookable?
    active? && staff_members.any?(&:active?)
  end

  Bookings.extend_model(self)
end
