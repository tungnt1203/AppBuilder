# The customer cancels their appointment, up to the cancellation notice (BookingSetting).
class Appointments::CancellationsController < ApplicationController
  before_action :require_booking

  def create
    appointment = Appointment.find_by!(token: params[:appointment_id])

    if appointment.cancellable_by_customer?
      appointment.cancel!(by: :customer)
      redirect_to appointment_path(appointment), notice: t(".notice"), status: :see_other
    else
      redirect_to appointment_path(appointment), alert: t(".too_late"), status: :see_other
    end
  end
end
