class Admin::Appointments::NoShowsController < Admin::BaseController
  include Admin::AppointmentTransition

  def create
    transition { @appointment.mark_no_show! }
  end
end
