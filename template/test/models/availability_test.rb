require "test_helper"

class AvailabilityTest < ActiveSupport::TestCase
  setup do
    @haircut = services(:haircut)
    @day = bookable_time.to_date
  end

  test "offers every slot from opening until the service no longer fits" do
    times = Availability.new(@haircut, @day).slots.map { |slot| slot.starts_at.strftime("%H:%M") }

    assert_equal "09:00", times.first
    assert_equal "16:00", times.last # 60 minutes until 17:00
    assert_not_includes times, "16:30"
  end

  test "a slot lists everyone free then; a booked staff member drops out of it" do
    slot = Availability.new(@haircut, @day).slots.find { |each| each.starts_at == bookable_time(10) }
    assert_equal [ staff_members(:linh) ], slot.staff_members # Mai has the 10:00 appointment

    assert_equal [ staff_members(:mai), staff_members(:linh) ].sort, Availability.new(@haircut, @day).staff_free_at(bookable_time(9)).sort
  end

  test "an overlapping appointment blocks the slots it touches, for that staff member" do
    mai = Availability.new(@haircut, @day, staff_member: staff_members(:mai)).slots.map(&:starts_at)

    assert_not_includes mai, bookable_time(9, 30) # would run into 10:00
    assert_not_includes mai, bookable_time(10, 30)
    assert_includes mai, bookable_time(9)
    assert_includes mai, bookable_time(11)
  end

  test "time off and closures block their times" do
    TimeOff.create!(staff_member: staff_members(:linh), starts_at: bookable_time(9), ends_at: bookable_time(12))
    assert_equal [ staff_members(:mai) ], Availability.new(@haircut, @day).staff_free_at(bookable_time(9))

    TimeOff.create!(starts_at: @day.in_time_zone, ends_at: (@day + 1).in_time_zone)
    assert_empty Availability.new(@haircut, @day).slots
  end

  test "nothing before the booking notice, nothing past the days ahead, nothing on a day off" do
    settings = BookingSetting.current
    now = @day.in_time_zone.change(hour: 9)
    times = Availability.new(@haircut, @day, now:).slots.map(&:starts_at)
    assert_equal now + settings.min_notice_minutes.minutes, times.first

    assert_empty Availability.new(@haircut, Date.current + settings.max_days_ahead + 1).slots
    assert_empty Availability.new(@haircut, Date.yesterday).slots

    WorkingHour.where(weekday: @day.wday).delete_all
    assert_empty Availability.new(@haircut.reload, @day).slots
  end

  test "only staff who do the service, and are taking bookings" do
    assert_equal [ staff_members(:mai) ], Availability.new(services(:consultation), @day).staff_free_at(bookable_time(9))

    staff_members(:mai).update!(active: false)
    assert_empty Availability.new(services(:consultation).reload, @day).slots
  end

  test "staff can book any free time within the hours, not only the offered ones" do
    assert_equal [ staff_members(:mai) ], Availability.new(@haircut, @day, staff_member: staff_members(:mai)).staff_free_at(bookable_time(11, 10))
    assert_empty Availability.new(@haircut, @day, staff_member: staff_members(:mai)).staff_free_at(bookable_time(16, 10))
  end
end
