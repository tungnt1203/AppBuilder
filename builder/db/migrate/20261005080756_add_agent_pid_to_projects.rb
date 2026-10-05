class AddAgentPidToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :agent_pid, :integer
  end
end
