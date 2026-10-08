require "test_helper"

class Admin::BookingSettingsControllerTest < ActionDispatch::IntegrationTest
  setup { enable_booking }

  test "admins change how booking works" do
    sign_in_as users(:admin)
    patch admin_booking_settings_path, params: { booking_setting: { slot_minutes: 15, min_notice_minutes: 60, max_days_ahead: 30, cancel_notice_hours: 12 } }

    assert_redirected_to edit_admin_booking_settings_path
    assert_equal 15, BookingSetting.current.slot_minutes
  end

  test "staff can't" do
    sign_in_as users(:staff)
    get edit_admin_booking_settings_path
    assert_redirected_to admin_root_path
  end
end
