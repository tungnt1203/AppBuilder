# Shows a file the owner attached to a message, for the chat.
class Projects::AttachmentsController < ApplicationController
  def show
    project = Project.find_by!(slug: params[:project_id])
    message = project.messages.user.find(params[:message_id])
    attachment = Attachment.for(message).find { |attachment| attachment.name == params[:name] } or raise ActiveRecord::RecordNotFound

    response.headers["Content-Security-Policy"] = "sandbox" # an SVG can carry scripts; never run them here
    send_file attachment.path, type: attachment.content_type, disposition: "inline"
  end
end
