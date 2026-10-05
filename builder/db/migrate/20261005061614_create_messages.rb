class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :project, null: false, foreign_key: true
      t.string :role, null: false
      t.text :body, null: false, default: ""
      t.json :data, null: false, default: {}

      t.timestamps
    end
  end
end
