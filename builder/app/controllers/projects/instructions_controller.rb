class Projects::InstructionsController < ApplicationController
  def update
    project = find_project(params[:project_id])

    if project.update(params.expect(project: [ :instructions ]))
      redirect_to project
    else
      render turbo_stream: turbo_stream.replace(helpers.dom_id(project, :instructions), partial: "projects/instructions", locals: { project: project }),
        status: :unprocessable_entity
    end
  end
end
