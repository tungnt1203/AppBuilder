class AddActivityToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :activity, :string
    add_column :projects, :working_since, :datetime
  end
end
