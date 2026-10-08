require "test_helper"

class Admin::TimeOffsControllerTest < ActionDispatch::IntegrationTest
  setup do
    enable_booking
    sign_in_as users(:staff)
  end

  test "closes the business for a day, then reopens" do
    day = bookable_time.to_date
    post admin_time_offs_path, params: { time_off: { staff_member_id: "", starts_at: "#{day.iso8601}T00:00", ends_at: "#{(day + 1).iso8601}T00:00", reason: "Holiday" } }
    assert_redirected_to admin_time_offs_path
    assert_empty Availability.new(services(:haircut), day).slots

    get admin_time_offs_path
    assert_select "li", /Whole business closed/

    delete admin_time_off_path(TimeOff.last)
    assert_not_empty Availability.new(services(:haircut), day).slots
  end
end
