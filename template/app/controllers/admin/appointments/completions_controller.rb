class Admin::Appointments::CompletionsController < Admin::BaseController
  include Admin::AppointmentTransition

  def create
    transition { @appointment.complete! }
  end
end
