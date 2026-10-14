class AddTemplateShaToProjects < ActiveRecord::Migration[8.1]
  def change
    # The template commit the app's code is from (set up from it, or updated to it), to bring it
    # the template's later changes. Apps made before have none: the commit before their setup.
    add_column :projects, :template_sha, :string
  end
end
