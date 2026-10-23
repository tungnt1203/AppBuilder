# A product prints what buyers add on more than one side (a photo on the front, a name on the
# back): a print area per side, { "front" => { x, y, w, h, pixels } }, instead of one, and a line's
# print file per side.
class PrintAreasPerSide < ActiveRecord::Migration[8.1]
  def up
    add_column :products, :print_areas, :jsonb, default: {}, null: false
    execute <<~SQL
      UPDATE products SET print_areas = jsonb_build_object(COALESCE(print_area->>'position', 'front'), print_area - 'position')
      WHERE print_area ? 'x'
    SQL
    remove_column :products, :print_area
    execute "UPDATE active_storage_attachments SET name = 'print_files' WHERE record_type = 'LineItem' AND name = 'print_file'"
  end

  def down
    add_column :products, :print_area, :jsonb, default: {}, null: false
    execute <<~SQL
      UPDATE products SET print_area = (SELECT value || jsonb_build_object('position', key) FROM jsonb_each(print_areas) ORDER BY key DESC LIMIT 1)
      WHERE print_areas <> '{}'
    SQL
    remove_column :products, :print_areas
    execute "UPDATE active_storage_attachments SET name = 'print_file' WHERE record_type = 'LineItem' AND name = 'print_files'"
  end
end
