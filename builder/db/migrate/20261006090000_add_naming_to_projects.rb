class AddNamingToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :name_pending, :boolean, default: false, null: false
    add_column :projects, :former_slug, :string
  end
end
