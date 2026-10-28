# The shop's own "not found" page, for any address the routes don't know (an old ad's link, a
# typo). A product or page the Platform doesn't have lands on the same page (ApplicationController).
class ErrorsController < ApplicationController
  def not_found
    render_not_found
  end
end
