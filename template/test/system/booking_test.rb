require "application_system_test_case"

class BookingTest < ApplicationSystemTestCase
  setup { enable_booking }

  test "a customer books on a phone, then staff see it on the day and complete it" do
    day = bookable_time.to_date

    on_phone do
      visit root_path
      click_on I18n.t("layouts.site.book")
      click_on "Haircut"
      click_on "Linh"
      find("a[href*='date=#{day.iso8601}']").click
      click_on I18n.l(bookable_time(14), format: :slot), exact: true

      fill_in Appointment.human_attribute_name(:name), with: "Robin Client"
      fill_in Appointment.human_attribute_name(:email), with: "robin@example.com"
      click_on I18n.t("bookings.new.book")

      assert_text I18n.t("appointments.show.booked", name: "Robin Client")
      assert_text "Linh"
    end

    appointment = Appointment.find_by!(email: "robin@example.com")
    assert_equal bookable_time(14), appointment.starts_at

    sign_in_as users(:staff)
    visit admin_appointments_path(date: day.iso8601)
    click_on "Robin Client"
    click_on I18n.t("admin.appointments.show.complete")
    assert_text I18n.t("admin.appointments.completions.create.notice", name: "Robin Client")
    assert appointment.reload.completed?
  end
end
