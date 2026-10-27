# Chats with the agent: start a new one (a new Claude session, the app as it is), open an
# earlier one (its next turn resumes its session), rename or delete one. Starting, opening
# and deleting wait until the agent isn't busy.
class Projects::ChatsController < ApplicationController
  before_action :set_project
  before_action :set_chat, only: %i[ update destroy open ]

  def create
    @project.start_chat unless @project.busy?
    redirect_to @project
  end

  def update
    @chat.update(params.expect(chat: [ :title ]))
    redirect_to @project
  end

  def destroy
    @project.delete_chat(@chat) unless @project.busy?
    redirect_to @project, status: :see_other
  end

  def open
    @project.switch_chat(@chat) unless @project.busy?
    redirect_to @project
  end

  private
    def set_project
      @project = find_project(params[:project_id])
    end

    def set_chat
      @chat = @project.chats.find(params[:id])
    end
end
