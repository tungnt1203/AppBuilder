class AddShowingProgressToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :showing_progress, :boolean, default: false, null: false
  end
end
