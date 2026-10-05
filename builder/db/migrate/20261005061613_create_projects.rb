class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :language, null: false, default: "en"
      t.integer :port, null: false
      t.string :status, null: false, default: "setting_up"
      t.string :session_id
      t.integer :preview_version, null: false, default: 0

      t.timestamps
    end
    add_index :projects, :slug, unique: true
    add_index :projects, :port, unique: true
  end
end
