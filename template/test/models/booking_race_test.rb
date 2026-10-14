require "test_helper"

# Two visitors booking the same staff member at the same moment, each on its own database
# connection (not inside a test transaction): only one of them gets the time.
class BookingRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    enable_booking
    @mai = staff_members(:mai)
    @before = Appointment.pluck(:id)
  end

  teardown do
    Appointment.where.not(id: @before).delete_all
  end

  test "the second of two bookings placed at once for the same staff member is refused" do
    # Both have read the free times before either writes, as close together as two requests get.
    reading = Queue.new
    original = Availability.instance_method(:staff_free_at)
    Availability.define_method(:staff_free_at) do |*args|
      original.bind_call(self, *args).tap { reading << true; sleep 0.3 }
    end

    results = 2.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Booking.new(service_id: services(:haircut).id, staff_member_id: @mai.id, starts_at: bookable_time(9).iso8601,
            name: "Visitor #{index}", email: "visitor#{index}@example.com").place
        end
      end
    end.map(&:value)

    assert_equal 1, results.compact.size
    assert_equal 1, Appointment.booked.where(staff_member: @mai, starts_at: bookable_time(9)).count
  ensure
    Availability.define_method(:staff_free_at, original)
  end
end
