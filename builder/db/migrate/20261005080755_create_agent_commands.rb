class CreateAgentCommands < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_commands do |t|
      t.references :project, null: false, foreign_key: true
      t.string :kind, null: false
      t.json :payload, null: false, default: {}
      t.datetime :delivered_at

      t.timestamps
    end
  end
end
