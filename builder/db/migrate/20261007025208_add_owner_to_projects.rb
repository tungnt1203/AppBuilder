class AddOwnerToProjects < ActiveRecord::Migration[8.1]
  # Apps made before there were accounts have no owner until the first account is
  # created; that account takes them over (see User#adopt_ownerless_projects).
  def change
    add_reference :projects, :owner, foreign_key: { to_table: :users }
  end
end
