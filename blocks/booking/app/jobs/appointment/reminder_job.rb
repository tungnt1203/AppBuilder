# Reminds customers of their appointment the day before (config/recurring.yml runs it every
# hour): booked appointments in the next 24 hours, except ones booked in the last 12, whose
# confirmation is reminder enough.
class Appointment::ReminderJob < ApplicationJob
  def perform
    Appointment.booked.where(reminded_at: nil, starts_at: Time.current..24.hours.from_now)
      .where(created_at: ...12.hours.ago).find_each do |appointment|
      AppointmentMailer.reminder(appointment).deliver_later
      appointment.update_column(:reminded_at, Time.current)
    end
  end
end
