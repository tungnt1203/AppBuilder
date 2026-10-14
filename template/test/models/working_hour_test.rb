require "test_helper"

class WorkingHourTest < ActiveSupport::TestCase
  test "hours that end before they start end the next morning" do
    hours = staff_members(:mai).working_hours.build(weekday: 5, opens_at_text: "18:00", closes_at_text: "2:00")

    assert hours.valid?
    assert_equal [ 1080, 1560 ], [ hours.opens_at, hours.closes_at ]
    assert hours.overnight?
    assert_equal "2:00", hours.closes_at_text

    hours.closes_at_text = hours.closes_at_text # saved again from the form
    assert hours.valid?
    assert_equal 1560, hours.closes_at
  end

  test "hours can't start and end at the same time" do
    hours = staff_members(:mai).working_hours.build(weekday: 5, opens_at_text: "9:00", closes_at_text: "9:00")
    assert_not hours.valid?
    assert hours.errors.added?(:closes_at_text, :before_opening)
  end
end
