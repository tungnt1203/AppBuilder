require "test_helper"

class AppointmentTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup { @appointment = appointments(:upcoming) }

  test "the customer can cancel until the notice; staff at any time" do
    assert @appointment.cancellable_by_customer?

    @appointment.update!(starts_at: 2.hours.from_now, ends_at: 3.hours.from_now)
    assert_not @appointment.cancellable_by_customer?

    assert_enqueued_emails(1) { @appointment.cancel!(by: :staff) }
    assert @appointment.cancelled?
    assert_equal "staff", @appointment.cancelled_by
  end

  test "a customer's cancellation tells the shop too" do
    assert_enqueued_emails(2) { @appointment.cancel!(by: :customer) }
  end

  test "moves on only from booked" do
    @appointment.complete!
    assert @appointment.completed?
    assert_raises(Appointment::InvalidTransition) { @appointment.mark_no_show! }
    assert_raises(Appointment::InvalidTransition) { @appointment.cancel!(by: :staff) }
  end

  test "a cancelled appointment frees its time" do
    @appointment.cancel!(by: :staff)
    slot = Availability.new(services(:haircut), @appointment.starts_at.to_date).staff_free_at(@appointment.starts_at)
    assert_includes slot, staff_members(:mai)
  end

  test "the reminder goes once, the day before, not for ones just booked" do
    @appointment.update_columns(starts_at: 20.hours.from_now, ends_at: 21.hours.from_now, created_at: 3.days.ago)
    just_booked = Appointment.create!(@appointment.attributes.except("id", "token", "created_at", "updated_at").merge("staff_member_id" => staff_members(:linh).id))

    assert_enqueued_emails(1) { Appointment::ReminderJob.perform_now }
    assert @appointment.reload.reminded_at
    assert_nil just_booked.reload.reminded_at
    assert_no_enqueued_emails { Appointment::ReminderJob.perform_now }
  end
end
