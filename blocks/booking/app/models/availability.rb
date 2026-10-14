# The times a service can be booked on a day: every slot_minutes from when each staff member who
# offers it starts work, as long as the whole service fits in their hours and doesn't overlap
# their appointments, their time off or the business being closed. Times are in the app's time
# zone; none earlier than the booking notice allows, no day past the last bookable one. Hours
# that run past midnight (18:00–2:00) give the day's late times and the next day's early ones,
# and a service can run across midnight.
#
#   Availability.new(service, Date.tomorrow).slots
#   # => [#<Slot starts_at: 9:00, staff_members: [Mai, Linh]>, #<Slot starts_at: 9:30, …>, …]
class Availability
  Slot = Data.define(:starts_at, :staff_members)

  def initialize(service, date, staff_member: nil, settings: BookingSetting.current, now: Time.current, ignore_notice: false)
    @service, @date, @settings, @now = service, date.to_date, settings, now
    @staff_members = service.staff_members.select(&:active?)
    @staff_members &= [ staff_member ] if staff_member
    @ignore_notice = ignore_notice
  end

  def slots
    return [] unless bookable_day?

    @staff_members.flat_map { |staff_member| starts_for(staff_member).map { |time| [ time, staff_member ] } }
      .group_by(&:first).sort_by(&:first)
      .map { |starts_at, pairs| Slot.new(starts_at:, staff_members: pairs.map(&:last)) }
  end

  # The staff members free for the whole service from starts_at: within their hours and not busy.
  # Any time works, not only the ones offered (staff book a walk-in at 9:10).
  def staff_free_at(starts_at)
    return [] unless bookable_day? && starts_at.in_time_zone.to_date == @date && (@ignore_notice || starts_at >= @settings.earliest_start(@now))

    @staff_members.select { |staff_member| free?(staff_member, starts_at) }
  end

  private
    def bookable_day?
      @service.active? && (@ignore_notice || (@date >= @now.to_date && @date <= @settings.last_day(@now)))
    end

    def starts_for(staff_member)
      shifts(staff_member).flat_map do |first, closes|
        last = closes - @service.duration
        times = (0..).lazy.map { |step| first + (step * @settings.slot_minutes).minutes }.take_while { |time| time <= last }
        times.select { |time| time.to_date == @date && (@ignore_notice || time >= @settings.earliest_start(@now)) && !busy?(staff_member, time) }.to_a
      end
    end

    def free?(staff_member, starts_at)
      ends_at = starts_at + @service.duration
      shifts(staff_member).any? { |opens, closes| starts_at >= opens && ends_at <= closes } && !busy?(staff_member, starts_at)
    end

    # [[opens, closes], …] as times: the day's hours, and the previous day's that run past midnight.
    def shifts(staff_member)
      previous = staff_member.hours_on(@date.prev_day.wday).select { |_, closes_at| closes_at > WorkingHour::DAY }
      previous.map { |opens_at, closes_at| [ at(opens_at - WorkingHour::DAY), at(closes_at - WorkingHour::DAY) ] } +
        staff_member.hours_on(@date.wday).map { |opens_at, closes_at| [ at(opens_at), at(closes_at) ] }
    end

    def busy?(staff_member, starts_at)
      ends_at = starts_at + @service.duration
      busy_times(staff_member).any? { |from, to| starts_at < to && ends_at > from }
    end

    # [[from, to], …]: the staff member's appointments, their time off and the business closed.
    def busy_times(staff_member)
      @busy_times ||= {}
      @busy_times[staff_member.id] ||= begin
        day = at(0)...at(2 * WorkingHour::DAY) # with the hours that run into the next morning
        Appointment.booked.where(staff_member:).overlapping(day).pluck(:starts_at, :ends_at) +
          TimeOff.for_staff_member(staff_member).overlapping(day).pluck(:starts_at, :ends_at)
      end
    end

    def at(minutes)
      @date.in_time_zone + minutes.minutes
    end
end
