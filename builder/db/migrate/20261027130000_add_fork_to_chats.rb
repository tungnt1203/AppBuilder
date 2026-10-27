# A chat can start as a copy of another (a fork): it shows the earlier chat's messages, and its
# first turn resumes that chat's session as a new one (--fork-session), leaving the original as it was.
class AddForkToChats < ActiveRecord::Migration[8.1]
  def change
    add_reference :chats, :forked_from, foreign_key: { to_table: :chats, on_delete: :nullify }
    add_column :chats, :fork_session, :boolean, default: false, null: false
  end
end
