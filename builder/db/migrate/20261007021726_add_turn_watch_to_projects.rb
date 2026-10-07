class AddTurnWatchToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :turn_heartbeat_at, :datetime
    add_column :projects, :turn_worker_pid, :integer
  end
end
