class Projects::ThumbnailsController < ApplicationController
  def show
    thumbnail = find_project(params[:project_id]).thumbnail
    return head :not_found unless thumbnail.exist?

    expires_in 1.year if params[:v] # the URL changes with each new picture
    send_file thumbnail.path, type: "image/png", disposition: "inline"
  end
end
