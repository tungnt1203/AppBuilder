# The customer's page for their appointment, reached by its unguessable token (from the booking
# and the emails), where they can cancel it.
class AppointmentsController < ApplicationController
  before_action :require_booking

  def show
    @appointment = Appointment.find_by!(token: params[:id])
    @settings = BookingSetting.current
    @store = Store.current
  end
end
