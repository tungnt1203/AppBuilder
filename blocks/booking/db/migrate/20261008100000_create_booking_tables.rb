class CreateBookingTables < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :duration_minutes, null: false, default: 60
      t.integer :price_cents, null: false, default: 0
      t.string :status, null: false, default: "active"
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :services, :slug, unique: true

    create_table :staff_members do |t|
      t.string :name, null: false
      t.text :bio
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    create_table :service_staff_members do |t|
      t.references :service, null: false, foreign_key: true
      t.references :staff_member, null: false, foreign_key: true
    end
    add_index :service_staff_members, [ :service_id, :staff_member_id ], unique: true

    # Minutes from midnight: 9:00–17:30 is 540–1050. A day can have several (a lunch break).
    create_table :working_hours do |t|
      t.references :staff_member, null: false, foreign_key: true
      t.integer :weekday, null: false
      t.integer :opens_at, null: false
      t.integer :closes_at, null: false
    end
    add_index :working_hours, [ :staff_member_id, :weekday ]

    # A staff member's time off, or the whole business closed (no staff member).
    create_table :time_offs do |t|
      t.references :staff_member, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :reason

      t.timestamps
    end
    add_index :time_offs, [ :starts_at, :ends_at ]

    create_table :appointments do |t|
      t.references :service, foreign_key: { on_delete: :nullify }
      t.references :staff_member, foreign_key: { on_delete: :nullify }
      t.references :customer, foreign_key: { on_delete: :nullify }
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, null: false, default: "booked"
      t.string :service_name, null: false
      t.integer :price_cents, null: false, default: 0
      t.string :currency, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.text :note
      t.text :staff_note
      t.string :token, null: false
      t.string :cancelled_by
      t.datetime :cancelled_at
      t.datetime :reminded_at

      t.timestamps
    end
    add_index :appointments, :token, unique: true
    add_index :appointments, [ :status, :starts_at ]
    add_index :appointments, [ :staff_member_id, :starts_at ]

    create_table :booking_settings do |t|
      t.integer :slot_minutes, null: false, default: 30
      t.integer :min_notice_minutes, null: false, default: 120
      t.integer :max_days_ahead, null: false, default: 60
      t.integer :cancel_notice_hours, null: false, default: 24

      t.timestamps
    end
  end
end
