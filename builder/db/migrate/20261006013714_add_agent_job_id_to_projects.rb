class AddAgentJobIdToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :agent_job_id, :string
  end
end
