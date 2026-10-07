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

ActiveRecord::Schema[8.1].define(version: 2026_10_07_100000) do
  create_table "agent_commands", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "kind", null: false
    t.json "payload", default: {}, null: false
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_agent_commands_on_project_id"
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

  create_table "messages", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "role", null: false
    t.text "body", default: "", null: false
    t.json "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_messages_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "language", default: "en", null: false
    t.integer "port", null: false
    t.string "status", default: "setting_up", null: false
    t.string "session_id"
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
    t.decimal "session_cost_usd", precision: 10, scale: 4, default: "0.0", null: false
    t.index ["eval_run"], name: "index_projects_on_eval_run"
    t.index ["owner_id"], name: "index_projects_on_owner_id"
    t.index ["port"], name: "index_projects_on_port", unique: true
    t.index ["share_token"], name: "index_projects_on_share_token", unique: true
    t.index ["slug"], name: "index_projects_on_slug", unique: true
    t.index ["subdomain"], name: "index_projects_on_subdomain", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
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

  add_foreign_key "agent_commands", "projects"
  add_foreign_key "deployments", "projects"
  add_foreign_key "messages", "projects"
  add_foreign_key "projects", "users", column: "owner_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "usages", "projects", on_delete: :nullify
  add_foreign_key "usages", "users"
end
