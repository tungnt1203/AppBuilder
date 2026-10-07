class Projects::MessagesController < ApplicationController
  def create
    @project = Project.find_by!(slug: params[:project_id])
    request = params.dig(:message, :body).to_s.strip
    files = Array(params.dig(:message, :files)).compact_blank

    if (request.present? || files.any?) && (@project.accepts_messages? || @project.accepts_messages_while_working?)
      @project.ask(request, mode: params.dig(:message, :plan) == "1" ? "plan" : "build", files:)
    end

    redirect_to @project
  end
end
