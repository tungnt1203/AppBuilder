class CreateDeployments < ActiveRecord::Migration[8.1]
  def change
    create_table :deployments do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :version, null: false
      t.string :image, null: false
      t.string :status, null: false, default: "building"
      t.string :commit_sha
      t.text :log, null: false, default: ""

      t.timestamps
    end
    add_index :deployments, [ :project_id, :version ], unique: true
  end
end
