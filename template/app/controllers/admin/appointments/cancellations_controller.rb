# Staff can cancel an appointment at any time; the customer gets an email.
class Admin::Appointments::CancellationsController < Admin::BaseController
  include Admin::AppointmentTransition

  def create
    transition { @appointment.cancel!(by: :staff) }
  end
end
