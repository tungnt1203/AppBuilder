class Projects::AddressesController < ApplicationController
  def update
    project = find_project(params[:project_id])

    if !project.movable? || project.change_subdomain(params.expect(project: [ :subdomain ])[:subdomain])
      redirect_back_or_to root_path, status: :see_other
    else
      render turbo_stream: turbo_stream.replace(helpers.dom_id(project, :address), partial: "projects/address_form", locals: { project: project }),
        status: :unprocessable_entity
    end
  end
end
