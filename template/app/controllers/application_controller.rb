# The customers' site: every page outside /admin. Pages are public; a page only for signed-in
# customers adds `before_action :require_customer`. The owner's and staff's screens live in
# /admin and inherit from Admin::BaseController instead.
class ApplicationController < ActionController::Base
  include CustomerAuthentication, CurrentCart, ShopSwitch, BookingSwitch, Tracking, Pagination
  # Every browser gets the site, older phones and in-app browsers (Facebook's, Instagram's) too:
  # a buyer from an ad on an iPhone a few years old must see the product, not a 406. Don't add
  # allow_browser here; /admin has it (Admin::BaseController).

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
