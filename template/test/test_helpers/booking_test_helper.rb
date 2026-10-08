# Booking is off by default (config.x.booking). Tests of the booking screens turn it on for
# themselves: `setup { enable_booking }`.
module BookingTestHelper
  def enable_booking
    @booking_was = Rails.configuration.x.booking unless defined?(@booking_was)
    Rails.configuration.x.booking = true
  end

  def after_teardown
    Rails.configuration.x.booking = @booking_was if defined?(@booking_was)
    super
  end

  # The day after tomorrow in the app's time zone at hour:minute, a time Mai and Linh both work.
  def bookable_time(hour = 9, minute = 0)
    2.days.from_now.to_date.in_time_zone.change(hour:, min: minute)
  end
end

ActiveSupport.on_load(:active_support_test_case) { include BookingTestHelper }
