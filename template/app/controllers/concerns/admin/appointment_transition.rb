# Shared by the controllers that move an appointment on (Admin::Appointments::*Controller).
module Admin::AppointmentTransition
  extend ActiveSupport::Concern

  included do
    before_action :require_booking
    before_action :set_appointment
  end

  private
    def set_appointment
      @appointment = Appointment.find_by!(token: params[:appointment_id])
    end

    def transition
      yield
      redirect_to admin_appointment_path(@appointment), notice: t(".notice", name: @appointment.name), status: :see_other
    rescue Appointment::InvalidTransition
      redirect_to admin_appointment_path(@appointment), alert: t("admin.appointments.invalid_transition"), status: :see_other
    end
end
