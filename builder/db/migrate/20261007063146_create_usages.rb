class CreateUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :usages do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, foreign_key: { on_delete: :nullify }
      t.decimal :cost_usd, precision: 10, scale: 4, null: false
      t.timestamps
    end
    add_index :usages, [ :user_id, :created_at ]
  end
end
