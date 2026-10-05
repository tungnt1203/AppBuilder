class AddPlanningToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :planning, :boolean, null: false, default: false
  end
end
