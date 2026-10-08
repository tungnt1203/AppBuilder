require "test_helper"

class BookingsControllerTest < ActionDispatch::IntegrationTest
  test "booking doesn't exist while it's off" do
    get new_booking_path
    assert_response :not_found
    get appointment_path(appointments(:upcoming))
    assert_response :not_found
  end

  test "picks a service, a day, a time, then books as a guest" do
    enable_booking
    User.delete_all

    get new_booking_path
    assert_select "a[href=?]", new_booking_path(service: "haircut")

    get new_booking_path(service: "haircut", date: bookable_time.to_date.iso8601)
    assert_select "a", text: "Anyone"
    assert_select "a[href*=?]", CGI.escape(bookable_time(9).iso8601)

    get new_booking_path(service: "haircut", date: bookable_time.to_date.iso8601, time: bookable_time(9).iso8601)
    assert_select "form[action=?]", booking_path

    assert_difference -> { Appointment.count } do
      post booking_path, params: { booking: { service_id: services(:haircut).id, starts_at: bookable_time(9).iso8601,
        name: "Ana", email: "ana@example.com", phone: "", note: "" } }
    end
    appointment = Appointment.last
    assert_redirected_to appointment_path(appointment, booked: 1)

    follow_redirect!
    assert_select "h1", "Haircut"
    assert_select "button", "Cancel appointment"
  end

  test "a time taken meanwhile shows the day's times again, with the details kept" do
    enable_booking
    post booking_path, params: { booking: { service_id: services(:consultation).id, staff_member_id: staff_members(:mai).id,
      starts_at: bookable_time(10).iso8601, name: "Ana", email: "ana@example.com" } }

    assert_response :unprocessable_entity
    assert_select "input[value=?]", "ana@example.com"
    assert_match "no longer free", response.body
  end

  test "the customer cancels their appointment, until it's too late" do
    enable_booking
    appointment = appointments(:upcoming)

    post appointment_cancellation_path(appointment)
    assert_redirected_to appointment_path(appointment)
    assert appointment.reload.cancelled?

    late = Appointment.create!(appointment.attributes.except("id", "token", "status", "cancelled_at", "cancelled_by")
      .merge("starts_at" => 1.hour.from_now, "ends_at" => 2.hours.from_now))
    post appointment_cancellation_path(late)
    assert late.reload.booked?
  end
end
