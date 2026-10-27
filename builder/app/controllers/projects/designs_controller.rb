# The Design tab: the storefront's colors, fonts, corners and width, tried on live in the
# preview and saved as a version without a turn of the agent (ProjectDesign).
class Projects::DesignsController < ApplicationController
  before_action :set_project

  def show
    @design = ProjectDesign.for(@project)
  end

  def update
    @design = ProjectDesign.for(@project)
    @design.assign_attributes(params.expect(design: %i[ brand background text accent heading_font text_font corners width ]))

    if !@project.accepts_messages?
      @design.errors.add(:base, "Wait until the current step finishes.")
      render :show, status: :unprocessable_entity
    elsif @design.save
      # The studio's own refresh skips the window that saved, so History is brought up to date here.
      render turbo_stream: [
        turbo_stream.update("design", partial: "projects/designs/panel", locals: { design: ProjectDesign.for(@project), project: @project, saved: true }),
        turbo_stream.update("versions", partial: "projects/versions", locals: { project: @project })
      ]
    else
      @design.errors.add(:base, "Nothing changed.") if @design.errors.empty?
      render :show, status: :unprocessable_entity
    end
  rescue ProjectShell::Error => error
    @design.errors.add(:base, "Saved as a version, but the preview's styles didn't rebuild: #{error.message.lines.first}")
    render :show, status: :unprocessable_entity
  end

  private
    def set_project
      @project = find_project(params[:project_id])
    end
end
