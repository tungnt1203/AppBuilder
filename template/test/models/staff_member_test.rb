require "test_helper"

class StaffMemberTest < ActiveSupport::TestCase
  test "weekly hours from the form: times as text, an empty day removed" do
    mai = staff_members(:mai)
    monday = mai.working_hours.find_by!(weekday: 1)

    mai.update!(working_hours_attributes: [
      { id: monday.id, weekday: 1, opens_at_text: "8:30", closes_at_text: "5:30 pm" },
      { id: mai.working_hours.find_by!(weekday: 0).id, weekday: 0, opens_at_text: "", closes_at_text: "" },
      { weekday: 1, opens_at_text: "", closes_at_text: "" }
    ])

    assert_equal [ [ 510, 1050 ] ], mai.reload.hours_on(1)
    assert_not mai.works_on?(0)
  end

  test "times must be times, and the end after the start" do
    mai = staff_members(:mai)
    assert_not mai.update(working_hours_attributes: [ { weekday: 3, opens_at_text: "nine", closes_at_text: "17:00" } ])
    assert_not mai.update(working_hours_attributes: [ { weekday: 3, opens_at_text: "17:00", closes_at_text: "9:00" } ])
  end

  test "reads times the way people write them" do
    assert_equal 540, WorkingHour.parse_time("9")
    assert_equal 570, WorkingHour.parse_time("9h30")
    assert_equal 1050, WorkingHour.parse_time("17.30")
    assert_equal 750, WorkingHour.parse_time("12:30 pm")
    assert_nil WorkingHour.parse_time("25:00")
  end
end
