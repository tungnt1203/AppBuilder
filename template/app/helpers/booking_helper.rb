# Pieces of booking shared by the site and /admin.
module BookingHelper
  APPOINTMENT_STATUS_TONES = { "booked" => :brand, "completed" => :green, "no_show" => :yellow, "cancelled" => :gray }.freeze

  def appointment_status_badge(appointment)
    badge t(appointment.status, scope: "appointments.statuses"), tone: APPOINTMENT_STATUS_TONES.fetch(appointment.status, :gray)
  end

  def weekday_name(weekday, format: :day_names)
    t("date.#{format}")[weekday]
  end

  # "Mon–Fri 9:00–17:00 · Sat 10:00–14:00", days with the same hours grouped.
  def working_hours_summary(staff_member)
    days = StaffMember::WEEKDAYS.rotate(1).map { |weekday| [ weekday, staff_member.hours_on(weekday) ] }.reject { |_, hours| hours.empty? }
    return t("booking.no_hours") if days.empty?

    days.chunk_while { |(day_a, hours_a), (day_b, hours_b)| hours_a == hours_b && (day_a + 1) % 7 == day_b }.map do |run|
      names = [ run.first, run.last ].uniq.map { |weekday, _| weekday_name(weekday, format: :abbr_day_names) }.join("–")
      hours = run.first.last.map { |from, to| "#{WorkingHour.format_time(from)}–#{WorkingHour.format_time(to)}" }.join(", ")
      "#{names} #{hours}"
    end.join(" · ")
  end

  # Durations in minutes for the service form.
  def duration_options
    [ 15, 20, 30, 45, 60, 75, 90, 120, 150, 180, 240 ].map { |minutes| [ t("booking.minutes", count: minutes), minutes ] }
  end
end
