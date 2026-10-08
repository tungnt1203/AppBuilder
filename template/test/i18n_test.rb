require "test_helper"

class I18nScreensTest < ActionDispatch::IntegrationTest
  setup { enable_customer_accounts }

  test "built-in screens have no missing translations" do
    [ root_path, new_session_path, new_registration_path, new_password_path, new_admin_session_path, new_admin_password_path ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end

    sign_in_as_customer customers(:casey)
    [ account_path, edit_account_path ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end

    sign_in_as users(:owner)
    [ admin_root_path, admin_users_path, new_admin_user_path, edit_admin_user_path(users(:staff)), admin_user_path(users(:staff)),
      admin_discounts_path, new_admin_discount_path, edit_admin_discount_path(discounts(:five_off)), admin_promotions_path, new_admin_promotion_path,
      edit_admin_product_path(products(:tee)), edit_admin_settings_path ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end
  end

  test "booking screens have no missing translations" do
    enable_booking
    appointment = appointments(:upcoming)
    day = bookable_time.to_date.iso8601
    [ new_booking_path, new_booking_path(service: "haircut", date: day), new_booking_path(service: "haircut", date: day, time: bookable_time(9).iso8601),
      appointment_path(appointment, booked: 1) ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end

    sign_in_as users(:owner)
    [ admin_root_path, admin_appointments_path, admin_appointments_path(date: appointment.starts_at.to_date.iso8601), admin_appointments_path(q: "casey"),
      admin_appointment_path(appointment), new_admin_appointment_path, admin_services_path, new_admin_service_path,
      edit_admin_service_path(services(:haircut)), admin_staff_members_path, new_admin_staff_member_path,
      edit_admin_staff_member_path(staff_members(:mai)), admin_time_offs_path, new_admin_time_off_path,
      edit_admin_booking_settings_path, edit_admin_settings_path ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end
  end

  private
    def assert_no_missing_translations
      assert_no_match(/translation[ _]missing/i, response.body, "Missing translation on #{request.path}")
    end
end
