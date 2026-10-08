class AddInstructionsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :instructions, :text
  end
end
