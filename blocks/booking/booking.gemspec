require_relative "lib/booking/version"

Gem::Specification.new do |spec|
  spec.name = "booking"
  spec.version = Bookings::VERSION
  spec.summary = "Appointments for apps made with AppBuilder: services, staff and their hours, free times, bookings, reminders"
  spec.authors = [ "AppBuilder" ]
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "README.md"]

  spec.add_dependency "rails", ">= 8.1"
end
