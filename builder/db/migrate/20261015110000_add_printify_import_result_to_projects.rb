class AddPrintifyImportResultToProjects < ActiveRecord::Migration[8.1]
  def change
    # What the last import of Printify products into the app from /admin/products brought in.
    add_column :projects, :printify_import_result, :json
    add_column :projects, :printify_imported_at, :datetime
  end
end
