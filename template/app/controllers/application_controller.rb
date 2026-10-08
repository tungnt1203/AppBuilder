# The customers' site: every page outside /admin. Pages are public; a page only for signed-in
# customers adds `before_action :require_customer`. The owner's and staff's screens live in
# /admin and inherit from Admin::BaseController instead.
class ApplicationController < ActionController::Base
  include CustomerAuthentication, CurrentCart, BookingSwitch, Pagination
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
