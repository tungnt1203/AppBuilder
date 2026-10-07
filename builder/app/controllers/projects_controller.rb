class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show update destroy ]

  def index
    set_listing
    @project = Project.new(language: "vi")
  end

  def create
    request = params.dig(:project, :request).to_s.strip
    @project = Current.user.projects.new(project_params)
    @project.name_after(request)

    if @project.save
      @project.messages.create!(role: :user, body: request) if request.present?
      ProjectSetupJob.perform_later(@project, request.presence, params.dig(:project, :plan) == "0" ? "build" : "plan")
      redirect_to @project
    else
      set_listing
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
    # Administrators can list every account's apps.
    def set_listing
      @everyone = Current.user.administrator? && params[:apps] == "all"
      @projects = (@everyone ? Project.all : Current.user.projects).listed.ordered.includes(:owner)
    end

    def set_project
      @project = find_project(params[:id])
    end

    def project_params
      params.expect(project: [ :name, :language ])
    end
end
