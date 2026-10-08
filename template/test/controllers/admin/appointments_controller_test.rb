require "test_helper"

class Admin::AppointmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    enable_booking
    sign_in_as users(:staff)
  end

  test "hidden while booking is off" do
    Rails.configuration.x.booking = false
    get admin_appointments_path
    assert_response :not_found

    get admin_root_path
    assert_select "a[href=?]", admin_appointments_path, count: 0
  end

  test "a day's appointments, and a search" do
    appointment = appointments(:upcoming)
    get admin_appointments_path(date: appointment.starts_at.to_date.iso8601)
    assert_select "a[href=?]", admin_appointment_path(appointment)

    get admin_appointments_path(q: "casey")
    assert_select "a[href=?]", admin_appointment_path(appointment)
  end

  test "staff book a walk-in at any free time" do
    assert_difference -> { Appointment.count } do
      post admin_appointments_path, params: { booking: { service_id: services(:haircut).id, staff_member_id: staff_members(:linh).id,
        starts_at: bookable_time(11, 10).strftime("%Y-%m-%dT%H:%M"), name: "Walk In", email: "walk@example.com" } }
    end
    appointment = Appointment.last
    assert_redirected_to admin_appointment_path(appointment)
    assert_equal bookable_time(11, 10), appointment.starts_at
    assert_equal staff_members(:linh), appointment.staff_member
  end

  test "complete, no-show and cancel, and a staff note" do
    appointment = appointments(:upcoming)

    patch admin_appointment_path(appointment), params: { appointment: { staff_note: "Prefers short" } }
    assert_equal "Prefers short", appointment.reload.staff_note

    post admin_appointment_cancellation_path(appointment)
    assert appointment.reload.cancelled?
    assert_equal "staff", appointment.cancelled_by

    post admin_appointment_completion_path(appointment)
    assert appointment.reload.cancelled?
    assert_equal "This appointment has already moved on; nothing was changed.", flash[:alert]
  end
end
