# Someone customers book: a stylist, a therapist, a doctor, or a chair or room. Works the hours
# in working_hours each week, except for time off; does the services they're linked to.
class StaffMember < ApplicationRecord
  WEEKDAYS = (0..6).to_a.freeze # Sunday is 0, as in Date#wday

  has_many :service_staff_members, dependent: :destroy
  has_many :services, -> { ordered }, through: :service_staff_members
  has_many :working_hours, -> { order(:weekday, :opens_at) }, dependent: :destroy, inverse_of: :staff_member
  has_many :time_offs, dependent: :destroy
  has_many :appointments, dependent: :nullify
  has_one_attached :photo do |photo|
    photo.variant :thumb, resize_to_fill: [ 160, 160 ], format: :webp
    photo.variant :card, resize_to_fill: [ 600, 750 ], format: :webp
  end

  accepts_nested_attributes_for :working_hours, allow_destroy: true

  # From the weekly hours form: a day left empty is a day off (its hours are removed).
  def working_hours_attributes=(attributes)
    rows = attributes.respond_to?(:values) ? attributes.values : Array(attributes)
    rows = rows.map(&:to_h).map(&:with_indifferent_access).filter_map do |row|
      next row unless row[:opens_at_text].blank? && row[:closes_at_text].blank?
      row.merge(_destroy: "1") if row[:id].present?
    end
    super(rows)
  end

  validates :name, presence: true, length: { maximum: 200 }
  validates :bio, length: { maximum: 2000 }

  normalizes :name, with: ->(name) { name.squish }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  # [[opens_at, closes_at], …] in minutes from midnight, for that day of the week.
  def hours_on(weekday)
    working_hours.select { |hours| hours.weekday == weekday }.map { |hours| [ hours.opens_at, hours.closes_at ] }
  end

  def works_on?(weekday)
    hours_on(weekday).any?
  end

  Bookings.extend_model(self)
end
