# Time a staff member isn't available (a holiday, a doctor's visit), or the whole business is
# closed when it has no staff member. No appointments can be booked over it.
class TimeOff < ApplicationRecord
  belongs_to :staff_member, optional: true

  validates :starts_at, :ends_at, presence: true
  validates :reason, length: { maximum: 200 }
  validate :ends_after_start

  scope :overlapping, ->(range) { where(starts_at: ...range.end).where("time_offs.ends_at > ?", range.begin) }
  scope :for_staff_member, ->(staff_member) { where(staff_member: [ nil, staff_member ]) }
  scope :upcoming, -> { where(ends_at: Time.current..).order(:starts_at) }

  def whole_business?
    staff_member_id.nil?
  end

  private
    def ends_after_start
      errors.add(:ends_at, :before_start) if starts_at && ends_at && ends_at <= starts_at
    end

  Bookings.extend_model(self)
end
