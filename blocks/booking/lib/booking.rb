require "booking/version"
require "booking/engine"

# The gem is "booking"; its module is Bookings, since Booking is the model that books an appointment.
module Bookings
  # Core models end with `Bookings.extend_model(self)`. An app adds to one of them in
  # app/models/<model>/extension.rb (`module Service::Extension`), like the shop's models
  # (see Shop.extend_model): it adds to the model, it doesn't replace what the core does.
  def self.extend_model(model)
    model.include(model::Extension) if model.const_defined?(:Extension, false)
  end
end
