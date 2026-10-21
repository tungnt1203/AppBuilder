class ApplicationController < ActionController::Base
  # The previews' cookies belong to localhost, where the studio sends them, so a studio opened at
  # 127.0.0.1 shows every preview as private. In development it moves to localhost.
  before_action :move_to_localhost, if: -> { Rails.env.development? && request.host == "127.0.0.1" && (request.get? || request.head?) }

  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def move_to_localhost
      redirect_to request.url.sub("//127.0.0.1", "//localhost"), allow_other_host: true
    end

    # Someone else's app looks like one that doesn't exist.
    def find_project(slug)
      Current.user.accessible_projects.find_by!(slug:)
    end
end
