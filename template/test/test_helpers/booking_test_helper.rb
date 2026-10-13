# Tests start with booking off (config.x.booking), whatever the app sets, so the tests of booking
# being off keep passing in an app that turned it on. Tests of the booking screens turn it on for
# themselves: `setup { enable_booking }`.
module BookingTestHelper
  def before_setup
    @booking_was = Rails.configuration.x.booking
    Rails.configuration.x.booking = false
    super
  end

  def enable_booking
    Rails.configuration.x.booking = true
  end

  def after_teardown
    Rails.configuration.x.booking = @booking_was
    super
  end

  # The day after tomorrow in the app's time zone at hour:minute, a time Mai and Linh both work.
  def bookable_time(hour = 9, minute = 0)
    2.days.from_now.to_date.in_time_zone.change(hour:, min: minute)
  end
end

ActiveSupport.on_load(:active_support_test_case) { include BookingTestHelper }
