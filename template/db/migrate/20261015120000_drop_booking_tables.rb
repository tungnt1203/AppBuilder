class DropBookingTables < ActiveRecord::Migration[8.1]
  # Booking (appointments, services, staff hours) is no longer part of the product; its block is
  # gone, and these tables with it. Apps never turned it on, so they hold nothing.
  def up
    %i[ appointments service_staff_members working_hours time_offs staff_members services booking_settings ].each do |table|
      drop_table table, if_exists: true, force: :cascade
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
