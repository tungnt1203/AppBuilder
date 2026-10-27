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

ActiveRecord::Schema[8.1].define(version: 2026_10_27_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "agent_commands", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "kind", null: false
    t.json "payload", default: {}, null: false
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_agent_commands_on_project_id"
  end

  create_table "api_idempotency_keys", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "key", null: false
    t.string "fingerprint", null: false
    t.integer "response_status"
    t.jsonb "response_body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_api_idempotency_keys_on_created_at"
    t.index ["shop_id", "key"], name: "index_api_idempotency_keys_on_shop_id_and_key", unique: true
  end

  create_table "business_settings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.text "stripe_secret_key"
    t.text "printify_token"
    t.string "printify_shop_id"
    t.string "printify_shop_title"
    t.string "meta_pixel_id"
    t.text "meta_access_token"
    t.string "tiktok_pixel_id"
    t.string "google_tag_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_publishable_key"
    t.index ["user_id"], name: "index_business_settings_on_user_id", unique: true
  end

  create_table "buyer_uploads", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "token", null: false
    t.integer "width"
    t.integer "height"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "created_at"], name: "index_buyer_uploads_on_shop_id_and_created_at"
    t.index ["shop_id"], name: "index_buyer_uploads_on_shop_id"
    t.index ["token"], name: "index_buyer_uploads_on_token", unique: true
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "cart_id", null: false
    t.bigint "variant_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "properties", default: {}, null: false
    t.index ["cart_id", "variant_id", "properties"], name: "index_cart_items_on_cart_id_and_variant_id_and_properties", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["shop_id"], name: "index_cart_items_on_shop_id"
    t.index ["variant_id"], name: "index_cart_items_on_variant_id"
  end

  create_table "carts", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "token", null: false
    t.string "discount_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "updated_at"], name: "index_carts_on_shop_id_and_updated_at"
    t.index ["shop_id"], name: "index_carts_on_shop_id"
    t.index ["token"], name: "index_carts_on_token", unique: true
  end

  create_table "chats", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "title"
    t.string "session_id"
    t.decimal "session_cost_usd", precision: 10, scale: 4, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "forked_from_id"
    t.boolean "fork_session", default: false, null: false
    t.index ["forked_from_id"], name: "index_chats_on_forked_from_id"
    t.index ["project_id"], name: "index_chats_on_project_id"
  end

  create_table "clipart_sets", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_clipart_sets_on_shop_id"
  end

  create_table "collection_products", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "collection_id", null: false
    t.bigint "product_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id", "product_id"], name: "index_collection_products_on_collection_id_and_product_id", unique: true
    t.index ["collection_id"], name: "index_collection_products_on_collection_id"
    t.index ["product_id"], name: "index_collection_products_on_product_id"
    t.index ["shop_id"], name: "index_collection_products_on_shop_id"
  end

  create_table "collections", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.boolean "demo", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "slug"], name: "index_collections_on_shop_id_and_slug", unique: true
    t.index ["shop_id"], name: "index_collections_on_shop_id"
  end

  create_table "custom_field_definitions", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.string "field_type", default: "text", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "key"], name: "index_custom_field_definitions_on_shop_id_and_key", unique: true
    t.index ["shop_id"], name: "index_custom_field_definitions_on_shop_id"
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "email_address"], name: "index_customers_on_shop_id_and_email_address", unique: true
    t.index ["shop_id"], name: "index_customers_on_shop_id"
  end

  create_table "deployments", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "version", null: false
    t.string "image", null: false
    t.string "status", default: "building", null: false
    t.string "commit_sha"
    t.text "log", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "version"], name: "index_deployments_on_project_id_and_version", unique: true
    t.index ["project_id"], name: "index_deployments_on_project_id"
  end

  create_table "discounts", force: :cascade do |t|
    t.bigint "shop_id", null: false
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
    t.index "shop_id, lower((code)::text)", name: "index_discounts_on_shop_id_and_code", unique: true
    t.index ["shop_id"], name: "index_discounts_on_shop_id"
  end

  create_table "form_submissions", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "form_id", null: false
    t.jsonb "answers", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["form_id", "created_at"], name: "index_form_submissions_on_form_id_and_created_at"
    t.index ["form_id"], name: "index_form_submissions_on_form_id"
    t.index ["shop_id"], name: "index_form_submissions_on_shop_id"
  end

  create_table "forms", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "key", null: false
    t.string "title", null: false
    t.jsonb "fields", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "key"], name: "index_forms_on_shop_id_and_key", unique: true
    t.index ["shop_id"], name: "index_forms_on_shop_id"
  end

  create_table "line_items", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "order_id", null: false
    t.bigint "variant_id"
    t.string "product_title", null: false
    t.string "variant_title"
    t.string "sku"
    t.integer "unit_price_cents", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "properties", default: {}, null: false
    t.index ["order_id"], name: "index_line_items_on_order_id"
    t.index ["shop_id"], name: "index_line_items_on_shop_id"
    t.index ["variant_id"], name: "index_line_items_on_variant_id"
  end

  create_table "menus", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "key", null: false
    t.string "title", null: false
    t.jsonb "items", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "key"], name: "index_menus_on_shop_id_and_key", unique: true
    t.index ["shop_id"], name: "index_menus_on_shop_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "role", null: false
    t.text "body", default: "", null: false
    t.json "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "chat_id", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["project_id"], name: "index_messages_on_project_id"
  end

  create_table "order_events", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "order_id", null: false
    t.bigint "user_id"
    t.string "action", null: false
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_events_on_order_id"
    t.index ["shop_id"], name: "index_order_events_on_shop_id"
    t.index ["user_id"], name: "index_order_events_on_user_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.integer "number", null: false
    t.string "token", null: false
    t.string "status", default: "pending", null: false
    t.bigint "customer_id"
    t.bigint "cart_id"
    t.bigint "discount_id"
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
    t.integer "discount_cents", default: 0, null: false
    t.string "discount_code"
    t.integer "shipping_cents", default: 0, null: false
    t.integer "tax_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.integer "refunded_cents", default: 0, null: false
    t.string "payment_method", default: "manual", null: false
    t.string "payment_reference"
    t.string "carrier"
    t.string "tracking_number"
    t.string "tracking_url"
    t.string "printify_order_id"
    t.text "fulfillment_error"
    t.integer "fulfillment_cost_cents"
    t.jsonb "attribution"
    t.datetime "paid_at"
    t.datetime "shipped_at"
    t.datetime "delivered_at"
    t.datetime "cancelled_at"
    t.datetime "refunded_at"
    t.datetime "restocked_at"
    t.datetime "recovery_sent_at"
    t.datetime "purchase_reported_at"
    t.datetime "review_requested_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "test", default: false, null: false
    t.string "stripe_payment_intent_id"
    t.string "stripe_tax_calculation_id"
    t.index ["cart_id"], name: "index_orders_on_cart_id"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["discount_id"], name: "index_orders_on_discount_id"
    t.index ["shop_id", "email"], name: "index_orders_on_shop_id_and_email"
    t.index ["shop_id", "number"], name: "index_orders_on_shop_id_and_number", unique: true
    t.index ["shop_id", "printify_order_id"], name: "index_orders_on_shop_id_and_printify_order_id"
    t.index ["shop_id", "status", "created_at"], name: "index_orders_on_shop_id_and_status_and_created_at"
    t.index ["shop_id"], name: "index_orders_on_shop_id"
    t.index ["stripe_payment_intent_id"], name: "index_orders_on_stripe_payment_intent_id", unique: true
    t.index ["token"], name: "index_orders_on_token", unique: true
  end

  create_table "pages", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.text "body"
    t.jsonb "faqs", default: [], null: false
    t.boolean "published", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "slug"], name: "index_pages_on_shop_id_and_slug", unique: true
    t.index ["shop_id"], name: "index_pages_on_shop_id"
  end

  create_table "platform_requests", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "project_id"
    t.text "body", null: false
    t.string "status", default: "open", null: false
    t.integer "times_asked", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_platform_requests_on_project_id"
    t.index ["shop_id", "status"], name: "index_platform_requests_on_shop_id_and_status"
    t.index ["shop_id"], name: "index_platform_requests_on_shop_id"
  end

  create_table "product_reviews", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "product_id", null: false
    t.bigint "order_id", null: false
    t.integer "rating", null: false
    t.text "body"
    t.string "author_name", null: false
    t.string "status", default: "published", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "product_id"], name: "index_product_reviews_on_order_id_and_product_id", unique: true
    t.index ["order_id"], name: "index_product_reviews_on_order_id"
    t.index ["product_id", "status", "created_at"], name: "index_product_reviews_on_product_id_and_status_and_created_at"
    t.index ["product_id"], name: "index_product_reviews_on_product_id"
    t.index ["shop_id"], name: "index_product_reviews_on_shop_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "status", default: "draft", null: false
    t.string "option1_name"
    t.string "option2_name"
    t.string "option3_name"
    t.jsonb "option1_values", default: [], null: false
    t.jsonb "option2_values", default: [], null: false
    t.jsonb "option3_values", default: [], null: false
    t.jsonb "option_images", default: {}, null: false
    t.jsonb "option_colors", default: {}, null: false
    t.text "size_guide"
    t.string "printify_product_id"
    t.boolean "demo", default: false, null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "custom_fields", default: {}, null: false
    t.jsonb "buyer_inputs", default: [], null: false
    t.jsonb "print_areas", default: {}, null: false
    t.index ["shop_id", "printify_product_id"], name: "index_products_on_shop_id_and_printify_product_id", unique: true, where: "(printify_product_id IS NOT NULL)"
    t.index ["shop_id", "slug"], name: "index_products_on_shop_id_and_slug", unique: true
    t.index ["shop_id", "status", "published_at"], name: "index_products_on_shop_id_and_status_and_published_at"
    t.index ["shop_id"], name: "index_products_on_shop_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "language", default: "en", null: false
    t.integer "port", null: false
    t.string "status", default: "setting_up", null: false
    t.integer "preview_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "base_sha"
    t.text "agent_note"
    t.string "activity"
    t.datetime "working_since"
    t.boolean "planning", default: false, null: false
    t.integer "agent_pid"
    t.string "agent_job_id"
    t.string "preview_status", default: "running", null: false
    t.text "preview_error"
    t.boolean "name_pending", default: false, null: false
    t.string "subdomain"
    t.string "eval_run"
    t.datetime "turn_heartbeat_at"
    t.integer "turn_worker_pid"
    t.integer "owner_id"
    t.string "share_token"
    t.text "instructions"
    t.string "template_sha"
    t.bigint "shop_id"
    t.text "preview_shop_key"
    t.text "live_shop_key"
    t.bigint "current_chat_id"
    t.index ["current_chat_id"], name: "index_projects_on_current_chat_id"
    t.index ["eval_run"], name: "index_projects_on_eval_run"
    t.index ["owner_id"], name: "index_projects_on_owner_id"
    t.index ["port"], name: "index_projects_on_port", unique: true
    t.index ["share_token"], name: "index_projects_on_share_token", unique: true
    t.index ["shop_id"], name: "index_projects_on_shop_id"
    t.index ["slug"], name: "index_projects_on_slug", unique: true
    t.index ["subdomain"], name: "index_projects_on_subdomain", unique: true
  end

  create_table "promotion_items", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "promotion_id", null: false
    t.bigint "variant_id", null: false
    t.integer "original_price_cents"
    t.integer "original_compare_at_price_cents"
    t.index ["promotion_id", "variant_id"], name: "index_promotion_items_on_promotion_id_and_variant_id", unique: true
    t.index ["promotion_id"], name: "index_promotion_items_on_promotion_id"
    t.index ["shop_id"], name: "index_promotion_items_on_shop_id"
    t.index ["variant_id"], name: "index_promotion_items_on_variant_id"
  end

  create_table "promotions", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "name", null: false
    t.integer "percent_off", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_promotions_on_shop_id"
    t.index ["status", "starts_at"], name: "index_promotions_on_status_and_starts_at"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shop_api_keys", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "kind", default: "storefront", null: false
    t.string "token_digest", null: false
    t.string "token_hint", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_shop_api_keys_on_shop_id"
    t.index ["token_digest"], name: "index_shop_api_keys_on_token_digest", unique: true
  end

  create_table "shop_memberships", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "staff", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "user_id"], name: "index_shop_memberships_on_shop_id_and_user_id", unique: true
    t.index ["shop_id"], name: "index_shop_memberships_on_shop_id"
    t.index ["user_id"], name: "index_shop_memberships_on_user_id"
  end

  create_table "shops", force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.string "uid", null: false
    t.string "currency", default: "USD", null: false
    t.string "time_zone", default: "UTC", null: false
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "business_synced_at"
    t.jsonb "business_sync_result"
    t.datetime "printify_imported_at"
    t.jsonb "printify_import_result"
    t.index ["subdomain"], name: "index_shops_on_subdomain", unique: true
    t.index ["uid"], name: "index_shops_on_uid", unique: true
  end

  create_table "stores", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "contact_email"
    t.string "contact_phone"
    t.text "business_address"
    t.integer "shipping_first_item_cents", default: 0, null: false
    t.integer "shipping_additional_item_cents", default: 0, null: false
    t.integer "free_shipping_threshold_cents"
    t.jsonb "ship_to_countries", default: [], null: false
    t.boolean "manual_payments", default: true, null: false
    t.text "payment_instructions"
    t.text "refund_policy"
    t.text "shipping_policy"
    t.text "privacy_policy"
    t.text "terms_of_service"
    t.integer "low_stock_threshold", default: 5, null: false
    t.string "announcement"
    t.integer "delivery_days_min"
    t.integer "delivery_days_max"
    t.text "stripe_secret_key"
    t.string "stripe_account_name"
    t.string "stripe_webhook_id"
    t.string "stripe_webhook_url"
    t.text "stripe_webhook_secret"
    t.boolean "stripe_tax", default: false, null: false
    t.text "printify_token"
    t.string "printify_shop_id"
    t.string "printify_shop_title"
    t.boolean "printify_send_to_production", default: true, null: false
    t.integer "printify_shipping_method", default: 1, null: false
    t.string "printify_webhook_url"
    t.text "printify_webhook_secret"
    t.jsonb "printify_webhook_ids", default: [], null: false
    t.string "meta_pixel_id"
    t.text "meta_access_token"
    t.string "meta_test_event_code"
    t.string "meta_error"
    t.string "tiktok_pixel_id"
    t.string "google_tag_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_publishable_key"
    t.index ["shop_id"], name: "index_stores_on_shop_id", unique: true
  end

  create_table "theme_settings", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.jsonb "schema", default: [], null: false
    t.string "schema_version"
    t.jsonb "values", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_theme_settings_on_shop_id", unique: true
  end

  create_table "usages", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "project_id"
    t.decimal "cost_usd", precision: 10, scale: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_usages_on_project_id"
    t.index ["user_id", "created_at"], name: "index_usages_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_usages_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", default: "", null: false
    t.string "role", default: "member", null: false
    t.datetime "toured_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "product_id", null: false
    t.string "option1"
    t.string "option2"
    t.string "option3"
    t.string "sku"
    t.integer "price_cents", default: 0, null: false
    t.integer "compare_at_price_cents"
    t.integer "cost_cents"
    t.boolean "available", default: true, null: false
    t.boolean "track_inventory", default: false, null: false
    t.integer "inventory_quantity", default: 0, null: false
    t.integer "printify_variant_id"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "option1", "option2", "option3"], name: "index_variants_on_product_and_options", unique: true
    t.index ["product_id", "position"], name: "index_variants_on_product_id_and_position"
    t.index ["product_id"], name: "index_variants_on_product_id"
    t.index ["shop_id"], name: "index_variants_on_shop_id"
  end

  create_table "webhook_events", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "provider", null: false
    t.string "event_id", null: false
    t.string "kind", null: false
    t.string "status", default: "received", null: false
    t.bigint "order_id"
    t.text "error"
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_webhook_events_on_order_id"
    t.index ["shop_id", "created_at"], name: "index_webhook_events_on_shop_id_and_created_at"
    t.index ["shop_id", "provider", "event_id"], name: "index_webhook_events_on_shop_id_and_provider_and_event_id", unique: true
    t.index ["shop_id"], name: "index_webhook_events_on_shop_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_commands", "projects"
  add_foreign_key "api_idempotency_keys", "shops"
  add_foreign_key "business_settings", "users"
  add_foreign_key "buyer_uploads", "shops"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "shops"
  add_foreign_key "cart_items", "variants"
  add_foreign_key "carts", "shops"
  add_foreign_key "chats", "chats", column: "forked_from_id", on_delete: :nullify
  add_foreign_key "chats", "projects"
  add_foreign_key "clipart_sets", "shops"
  add_foreign_key "collection_products", "collections"
  add_foreign_key "collection_products", "products"
  add_foreign_key "collection_products", "shops"
  add_foreign_key "collections", "shops"
  add_foreign_key "custom_field_definitions", "shops"
  add_foreign_key "customers", "shops"
  add_foreign_key "deployments", "projects"
  add_foreign_key "discounts", "shops"
  add_foreign_key "form_submissions", "forms"
  add_foreign_key "form_submissions", "shops"
  add_foreign_key "forms", "shops"
  add_foreign_key "line_items", "orders"
  add_foreign_key "line_items", "shops"
  add_foreign_key "line_items", "variants", on_delete: :nullify
  add_foreign_key "menus", "shops"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "projects"
  add_foreign_key "order_events", "orders"
  add_foreign_key "order_events", "shops"
  add_foreign_key "order_events", "users", on_delete: :nullify
  add_foreign_key "orders", "carts", on_delete: :nullify
  add_foreign_key "orders", "customers", on_delete: :nullify
  add_foreign_key "orders", "discounts", on_delete: :nullify
  add_foreign_key "orders", "shops"
  add_foreign_key "pages", "shops"
  add_foreign_key "platform_requests", "projects"
  add_foreign_key "platform_requests", "shops"
  add_foreign_key "product_reviews", "orders"
  add_foreign_key "product_reviews", "products"
  add_foreign_key "product_reviews", "shops"
  add_foreign_key "products", "shops"
  add_foreign_key "projects", "chats", column: "current_chat_id", on_delete: :nullify
  add_foreign_key "projects", "shops"
  add_foreign_key "projects", "users", column: "owner_id"
  add_foreign_key "promotion_items", "promotions"
  add_foreign_key "promotion_items", "shops"
  add_foreign_key "promotion_items", "variants", on_delete: :cascade
  add_foreign_key "promotions", "shops"
  add_foreign_key "sessions", "users"
  add_foreign_key "shop_api_keys", "shops"
  add_foreign_key "shop_memberships", "shops"
  add_foreign_key "shop_memberships", "users"
  add_foreign_key "stores", "shops"
  add_foreign_key "theme_settings", "shops"
  add_foreign_key "usages", "projects", on_delete: :nullify
  add_foreign_key "usages", "users"
  add_foreign_key "variants", "products"
  add_foreign_key "variants", "shops"
  add_foreign_key "webhook_events", "orders", on_delete: :nullify
  add_foreign_key "webhook_events", "shops"
end
