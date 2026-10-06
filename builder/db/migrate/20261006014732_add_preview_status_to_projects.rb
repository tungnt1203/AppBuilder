class AddPreviewStatusToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :preview_status, :string, null: false, default: "running"
    add_column :projects, :preview_error, :text
  end
end
