# Appointments (the booking block) are on when config.x.booking is. Off, their pages answer 404
# and the site and /admin don't link to them.
module BookingSwitch
  extend ActiveSupport::Concern

  included do
    helper_method :booking?
  end

  private
    def booking?
      Rails.configuration.x.booking
    end

    def require_booking
      head :not_found unless booking?
    end
end
