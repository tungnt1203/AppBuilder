# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_08_110003) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agent_changes", force: :cascade do |t|
    t.string "kind", null: false
    t.string "status", default: "staged", null: false
    t.string "summary", null: false
    t.json "payload", default: {}, null: false
    t.json "items", default: [], null: false
    t.json "guardrail_notes", default: [], null: false
    t.string "created_by", null: false
    t.string "created_by_kind", default: "agent", null: false
    t.string "applied_by"
    t.datetime "applied_at"
    t.string "discarded_by"
    t.string "discarded_by_kind"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status", "created_at"], name: "index_agent_changes_on_status_and_created_at"
  end

  create_table "appointments", force: :cascade do |t|
    t.integer "service_id"
    t.integer "staff_member_id"
    t.integer "customer_id"
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "status", default: "booked", null: false
    t.string "service_name", null: false
    t.integer "price_cents", default: 0, null: false
    t.string "currency", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.text "note"
    t.text "staff_note"
    t.string "token", null: false
    t.string "cancelled_by"
    t.datetime "cancelled_at"
    t.datetime "reminded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["service_id"], name: "index_appointments_on_service_id"
    t.index ["staff_member_id", "starts_at"], name: "index_appointments_on_staff_member_id_and_starts_at"
    t.index ["staff_member_id"], name: "index_appointments_on_staff_member_id"
    t.index ["status", "starts_at"], name: "index_appointments_on_status_and_starts_at"
    t.index ["token"], name: "index_appointments_on_token", unique: true
  end

  create_table "booking_settings", force: :cascade do |t|
    t.integer "slot_minutes", default: 30, null: false
    t.integer "min_notice_minutes", default: 120, null: false
    t.integer "max_days_ahead", default: 60, null: false
    t.integer "cancel_notice_hours", default: 24, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cart_items", force: :cascade do |t|
    t.integer "cart_id", null: false
    t.integer "variant_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "variant_id"], name: "index_cart_items_on_cart_id_and_variant_id", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["variant_id"], name: "index_cart_items_on_variant_id"
  end

  create_table "carts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "discount_code"
    t.string "agent_session_key"
    t.index ["agent_session_key"], name: "index_carts_on_agent_session_key", unique: true
    t.index ["updated_at"], name: "index_carts_on_updated_at"
  end

  create_table "collection_products", force: :cascade do |t|
    t.integer "collection_id", null: false
    t.integer "product_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id", "product_id"], name: "index_collection_products_on_collection_id_and_product_id", unique: true
    t.index ["collection_id"], name: "index_collection_products_on_collection_id"
    t.index ["product_id"], name: "index_collection_products_on_product_id"
  end

  create_table "collections", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_collections_on_slug", unique: true
  end

  create_table "customer_sessions", force: :cascade do |t|
    t.integer "customer_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_sessions_on_customer_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_customers_on_email_address", unique: true
  end

  create_table "discounts", force: :cascade do |t|
    t.string "code", null: false
    t.string "kind", default: "percentage", null: false
    t.integer "percent_off"
    t.integer "amount_off_cents"
    t.integer "minimum_subtotal_cents"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.integer "usage_limit"
    t.integer "times_used", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_discounts_on_code", unique: true
  end

  create_table "line_items", force: :cascade do |t|
    t.integer "order_id", null: false
    t.integer "variant_id"
    t.string "product_title", null: false
    t.string "variant_title"
    t.string "sku"
    t.integer "unit_price_cents", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_line_items_on_order_id"
    t.index ["variant_id"], name: "index_line_items_on_variant_id"
  end

  create_table "order_events", force: :cascade do |t|
    t.integer "order_id", null: false
    t.integer "user_id"
    t.string "action", null: false
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_events_on_order_id"
    t.index ["user_id"], name: "index_order_events_on_user_id"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "number", null: false
    t.string "token", null: false
    t.string "status", default: "pending", null: false
    t.integer "customer_id"
    t.string "email", null: false
    t.string "phone"
    t.string "shipping_name", null: false
    t.string "shipping_address1", null: false
    t.string "shipping_address2"
    t.string "shipping_city", null: false
    t.string "shipping_region"
    t.string "shipping_postal_code"
    t.string "shipping_country", null: false
    t.text "note"
    t.text "staff_note"
    t.string "currency", null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "shipping_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.string "payment_method", default: "manual", null: false
    t.string "payment_reference"
    t.string "carrier"
    t.string "tracking_number"
    t.string "tracking_url"
    t.datetime "paid_at"
    t.datetime "shipped_at"
    t.datetime "delivered_at"
    t.datetime "cancelled_at"
    t.datetime "refunded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_checkout_session_id"
    t.integer "cart_id"
    t.integer "discount_id"
    t.string "discount_code"
    t.integer "discount_cents", default: 0, null: false
    t.integer "tax_cents", default: 0, null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["discount_id"], name: "index_orders_on_discount_id"
    t.index ["email"], name: "index_orders_on_email"
    t.index ["number"], name: "index_orders_on_number", unique: true
    t.index ["status", "created_at"], name: "index_orders_on_status_and_created_at"
    t.index ["stripe_checkout_session_id"], name: "index_orders_on_stripe_checkout_session_id", unique: true
    t.index ["token"], name: "index_orders_on_token", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "status", default: "draft", null: false
    t.string "option1_name"
    t.string "option2_name"
    t.string "option3_name"
    t.json "option1_values", default: [], null: false
    t.json "option2_values", default: [], null: false
    t.json "option3_values", default: [], null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_products_on_slug", unique: true
    t.index ["status", "published_at"], name: "index_products_on_status_and_published_at"
  end

  create_table "promotion_items", force: :cascade do |t|
    t.integer "promotion_id", null: false
    t.integer "variant_id", null: false
    t.integer "original_price_cents"
    t.integer "original_compare_at_price_cents"
    t.index ["promotion_id", "variant_id"], name: "index_promotion_items_on_promotion_id_and_variant_id", unique: true
    t.index ["promotion_id"], name: "index_promotion_items_on_promotion_id"
    t.index ["variant_id"], name: "index_promotion_items_on_variant_id"
  end

  create_table "promotions", force: :cascade do |t|
    t.string "name", null: false
    t.integer "percent_off", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status", "starts_at"], name: "index_promotions_on_status_and_starts_at"
  end

  create_table "service_staff_members", force: :cascade do |t|
    t.integer "service_id", null: false
    t.integer "staff_member_id", null: false
    t.index ["service_id", "staff_member_id"], name: "index_service_staff_members_on_service_id_and_staff_member_id", unique: true
    t.index ["service_id"], name: "index_service_staff_members_on_service_id"
    t.index ["staff_member_id"], name: "index_service_staff_members_on_staff_member_id"
  end

  create_table "services", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "duration_minutes", default: 60, null: false
    t.integer "price_cents", default: 0, null: false
    t.string "status", default: "active", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_services_on_slug", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "staff_members", force: :cascade do |t|
    t.string "name", null: false
    t.text "bio"
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "stores", force: :cascade do |t|
    t.string "currency", default: "USD", null: false
    t.string "contact_email"
    t.integer "shipping_first_item_cents", default: 0, null: false
    t.integer "shipping_additional_item_cents", default: 0, null: false
    t.integer "free_shipping_threshold_cents"
    t.json "ship_to_countries", default: [], null: false
    t.text "payment_instructions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "stripe_secret_key"
    t.string "stripe_account_name"
    t.string "stripe_webhook_id"
    t.string "stripe_webhook_url"
    t.text "stripe_webhook_secret"
    t.boolean "manual_payments", default: true, null: false
    t.string "contact_phone"
    t.text "business_address"
    t.text "refund_policy"
    t.text "shipping_policy"
    t.text "privacy_policy"
    t.text "terms_of_service"
    t.integer "low_stock_threshold", default: 5, null: false
    t.boolean "stripe_tax", default: false, null: false
    t.string "storefront_agent_key_digest"
    t.string "merchant_agent_key_digest"
  end

  create_table "time_offs", force: :cascade do |t|
    t.integer "staff_member_id"
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_member_id"], name: "index_time_offs_on_staff_member_id"
    t.index ["starts_at", "ends_at"], name: "index_time_offs_on_starts_at_and_ends_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "role", default: "staff", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "option1"
    t.string "option2"
    t.string "option3"
    t.string "sku"
    t.integer "price_cents", default: 0, null: false
    t.integer "compare_at_price_cents"
    t.boolean "available", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "track_inventory", default: false, null: false
    t.integer "inventory_quantity", default: 0, null: false
    t.integer "cost_cents"
    t.index ["product_id", "option1", "option2", "option3"], name: "index_variants_on_product_and_options", unique: true
    t.index ["product_id", "position"], name: "index_variants_on_product_id_and_position"
    t.index ["product_id"], name: "index_variants_on_product_id"
  end

  create_table "working_hours", force: :cascade do |t|
    t.integer "staff_member_id", null: false
    t.integer "weekday", null: false
    t.integer "opens_at", null: false
    t.integer "closes_at", null: false
    t.index ["staff_member_id", "weekday"], name: "index_working_hours_on_staff_member_id_and_weekday"
    t.index ["staff_member_id"], name: "index_working_hours_on_staff_member_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointments", "customers", on_delete: :nullify
  add_foreign_key "appointments", "services", on_delete: :nullify
  add_foreign_key "appointments", "staff_members", on_delete: :nullify
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "variants"
  add_foreign_key "collection_products", "collections"
  add_foreign_key "collection_products", "products"
  add_foreign_key "customer_sessions", "customers"
  add_foreign_key "line_items", "orders"
  add_foreign_key "line_items", "variants", on_delete: :nullify
  add_foreign_key "order_events", "orders"
  add_foreign_key "order_events", "users", on_delete: :nullify
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "discounts", on_delete: :nullify
  add_foreign_key "promotion_items", "promotions"
  add_foreign_key "promotion_items", "variants", on_delete: :cascade
  add_foreign_key "service_staff_members", "services"
  add_foreign_key "service_staff_members", "staff_members"
  add_foreign_key "sessions", "users"
  add_foreign_key "time_offs", "staff_members"
  add_foreign_key "variants", "products"
  add_foreign_key "working_hours", "staff_members"
end
