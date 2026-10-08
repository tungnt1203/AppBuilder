# Emails to the customer about their appointment.
class AppointmentMailer < ApplicationMailer
  helper :money

  def confirmation(appointment)
    deliver_about appointment
  end

  def reminder(appointment)
    deliver_about appointment
  end

  def cancelled(appointment)
    deliver_about appointment
  end

  private
    def deliver_about(appointment)
      @appointment, @store = appointment, Store.current
      mail to: appointment.email, reply_to: @store.contact_email.presence,
        subject: t(".subject", app: Rails.configuration.x.app_name, service: appointment.service_name,
          time: I18n.l(appointment.starts_at, format: :appointment))
    end
end
