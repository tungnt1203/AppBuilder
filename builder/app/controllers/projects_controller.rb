class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show update destroy ]

  def index
    @projects = Project.ordered
    @project = Project.new(language: "vi")
  end

  def create
    request = params.dig(:project, :request).to_s.strip
    @project = Project.new(project_params)
    @project.name_after(request)

    if @project.save
      @project.messages.create!(role: :user, body: request) if request.present?
      ProjectSetupJob.perform_later(@project, request.presence, params.dig(:project, :plan) == "0" ? "build" : "plan")
      redirect_to @project
    else
      @projects = Project.ordered
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @project.ensure_preview
  end

  def update
    @project.rename(params.expect(project: [ :name ])[:name]) unless @project.busy?
    redirect_back_or_to root_path
  end

  def destroy
    @project.remove unless @project.busy?
    redirect_to root_path, status: :see_other
  end

  private
    def set_project
      @project = Project.find_by!(slug: params[:id])
    end

    def project_params
      params.expect(project: [ :name, :language ])
    end
end
