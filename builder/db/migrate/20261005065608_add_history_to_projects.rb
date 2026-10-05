class AddHistoryToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :base_sha, :string
    add_column :projects, :agent_note, :text
  end
end
