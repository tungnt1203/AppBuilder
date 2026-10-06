class AddEvalRunToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :eval_run, :string
    add_index :projects, :eval_run
  end
end
