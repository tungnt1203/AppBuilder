# Tells the owner and admins when a customer books or cancels.
class Admin::AppointmentMailer < ApplicationMailer
  helper :money

  def booked(appointment)
    deliver_about appointment
  end

  def cancelled(appointment)
    deliver_about appointment
  end

  private
    def deliver_about(appointment)
      @appointment = appointment
      recipients = User.where(role: %w[ owner admin ]).pluck(:email_address)
      return if recipients.empty?

      mail to: recipients, subject: t(".subject", name: appointment.name, service: appointment.service_name,
        time: I18n.l(appointment.starts_at, format: :appointment))
    end
end
