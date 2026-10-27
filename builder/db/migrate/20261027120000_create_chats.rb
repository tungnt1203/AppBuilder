# A project's chat becomes one of several: the owner can start a new chat with the agent (a new
# Claude session, the app as it is) and go back to an earlier one, which resumes its session.
# Each existing project's messages and session move into its first chat.
class CreateChats < ActiveRecord::Migration[8.1]
  def up
    create_table :chats do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title
      t.string :session_id
      t.decimal :session_cost_usd, precision: 10, scale: 4, default: "0.0", null: false
      t.timestamps
    end
    add_reference :messages, :chat, foreign_key: true
    add_reference :projects, :current_chat, foreign_key: { to_table: :chats, on_delete: :nullify }

    execute <<~SQL
      INSERT INTO chats (project_id, title, session_id, session_cost_usd, created_at, updated_at)
      SELECT projects.id,
        (SELECT LEFT(body, 80) FROM messages WHERE messages.project_id = projects.id AND role = 'user' AND body <> '' ORDER BY id LIMIT 1),
        projects.session_id, projects.session_cost_usd, projects.created_at, projects.updated_at
      FROM projects
    SQL
    execute "UPDATE messages SET chat_id = chats.id FROM chats WHERE chats.project_id = messages.project_id"
    execute "UPDATE projects SET current_chat_id = chats.id FROM chats WHERE chats.project_id = projects.id"
    change_column_null :messages, :chat_id, false

    remove_column :projects, :session_id
    remove_column :projects, :session_cost_usd
  end

  def down
    add_column :projects, :session_id, :string
    add_column :projects, :session_cost_usd, :decimal, precision: 10, scale: 4, default: "0.0", null: false
    execute <<~SQL
      UPDATE projects SET session_id = chats.session_id, session_cost_usd = chats.session_cost_usd
      FROM chats WHERE chats.id = projects.current_chat_id
    SQL
    remove_reference :projects, :current_chat, foreign_key: { to_table: :chats }
    remove_reference :messages, :chat, foreign_key: true
    drop_table :chats
  end
end
