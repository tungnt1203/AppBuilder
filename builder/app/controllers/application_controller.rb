class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    # Someone else's app looks like one that doesn't exist.
    def find_project(slug)
      Current.user.accessible_projects.find_by!(slug:)
    end
end
