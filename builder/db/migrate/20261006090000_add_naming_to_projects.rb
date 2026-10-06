# The app's name no longer decides its addresses: the studio path is a fixed id
# from creation, and the published subdomain is picked from the name on first publish.
class AddNamingToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :name_pending, :boolean, default: false, null: false
    add_column :projects, :subdomain, :string
    add_index :projects, :subdomain, unique: true

    # Existing apps keep the address they were published at.
    up_only { execute "UPDATE projects SET subdomain = slug" }
  end
end
