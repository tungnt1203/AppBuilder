class Projects::MessagesController < ApplicationController
  def create
    @project = Project.find_by!(slug: params[:project_id])
    request = params.dig(:message, :body).to_s.strip

    ask_id = params.dig(:message, :ask_id)

    if ask_id.present? && @project.working?
      @project.answer(ask_id, JSON.parse(params.dig(:message, :answers).presence || "{}"))
    elsif request.present? && (@project.accepts_messages? || @project.accepts_messages_while_working?)
      @project.ask(request, mode: params.dig(:message, :plan) == "1" ? "plan" : "build")
    end

    redirect_to @project
  end
end
