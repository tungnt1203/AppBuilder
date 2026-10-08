# How booking works, one row: the step between the times offered, how long before a booking must
# be made, how far ahead it can be, until when a customer can cancel. BookingSetting.current
# everywhere; the owner changes it at /admin/settings/booking.
class BookingSetting < ApplicationRecord
  SLOT_STEPS = [ 5, 10, 15, 20, 30, 45, 60, 90, 120 ].freeze

  validates :slot_minutes, inclusion: { in: SLOT_STEPS }
  validates :min_notice_minutes, numericality: { only_integer: true, in: 0..(30 * 24 * 60) }
  validates :max_days_ahead, numericality: { only_integer: true, in: 1..365 }
  validates :cancel_notice_hours, numericality: { only_integer: true, in: 0..(30 * 24) }

  def self.current
    first || create!
  end

  # The first moment a customer can book, and the last day they can book on.
  def earliest_start(now = Time.current)
    now + min_notice_minutes.minutes
  end

  def last_day(now = Time.current)
    now.to_date + max_days_ahead
  end

  Bookings.extend_model(self)
end
