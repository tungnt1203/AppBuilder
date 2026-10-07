# What the agent's current session has cost so far, as already counted: a resumed session
# reports its running total, so each turn is charged the difference.
class AddSessionCostUsdToProjects < ActiveRecord::Migration[8.1]
  def up
    add_column :projects, :session_cost_usd, :decimal, precision: 10, scale: 4, default: 0, null: false

    select_rows("SELECT id FROM projects WHERE session_id IS NOT NULL").flatten.each do |id|
      data = select_value("SELECT data FROM messages WHERE project_id = #{id.to_i} AND role = 'result' ORDER BY id DESC LIMIT 1")
      total = JSON.parse(data.to_s)["total_cost_usd"] rescue nil
      execute "UPDATE projects SET session_cost_usd = #{total.to_f} WHERE id = #{id.to_i}" if total
    end
  end

  def down
    remove_column :projects, :session_cost_usd
  end
end
