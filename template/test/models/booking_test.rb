require "test_helper"

class BookingTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def booking(**attributes)
    Booking.new(service_id: services(:haircut).id, starts_at: bookable_time(9).iso8601, name: "Ana", email: "ana@example.com", **attributes)
  end

  test "books a free time with whoever is free, copying the service's name and price" do
    appointment = nil
    assert_enqueued_emails(2) { appointment = booking.place }

    assert appointment.persisted?
    assert_equal bookable_time(9), appointment.starts_at
    assert_equal bookable_time(10), appointment.ends_at
    assert_equal "Haircut", appointment.service_name
    assert_equal 4000, appointment.price_cents
    assert_equal "USD", appointment.currency
    assert_includes [ staff_members(:mai), staff_members(:linh) ], appointment.staff_member
  end

  test "books the staff member asked for" do
    assert_equal staff_members(:linh), booking(staff_member_id: staff_members(:linh).id).place.staff_member
  end

  test "a time already taken is refused" do
    attempt = booking(staff_member_id: staff_members(:mai).id, starts_at: bookable_time(10).iso8601)

    assert_no_difference -> { Appointment.count } do
      assert_nil attempt.place
    end
    assert attempt.errors.added?(:starts_at, :taken)
  end

  test "the second booking of the last free staff member is refused" do
    booking.place
    booking(email: "bo@example.com").place
    third = booking(email: "cy@example.com")

    assert_nil third.place
    assert third.errors.added?(:starts_at, :taken)
  end

  test "outside the hours, or too soon, is refused; staff can book within the notice" do
    assert_nil booking(starts_at: bookable_time(16, 30).iso8601).place
    assert_nil booking(starts_at: 30.minutes.from_now.iso8601).place

    soon = Time.current.change(min: 0) + 1.hour
    WorkingHour.where(weekday: soon.wday).update_all(opens_at: 0, closes_at: 24 * 60)
    staff_booking = booking(starts_at: soon.iso8601)
    staff_booking.by_staff = true
    assert staff_booking.place if soon.to_date == (soon + 1.hour).to_date
  end

  test "needs a service, a name and a valid email" do
    attempt = Booking.new(starts_at: bookable_time(9).iso8601, email: "ana@example")
    assert_nil attempt.place
    assert attempt.errors.added?(:service, :blank)
    assert attempt.errors.added?(:name, :blank)
    assert attempt.errors.of_kind?(:email, :invalid)
  end
end
