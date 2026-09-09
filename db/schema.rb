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

ActiveRecord::Schema.define(version: 2026_09_09_010000) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounting_lists", force: :cascade do |t|
    t.string "accounting_type"
    t.string "vendor"
    t.decimal "amount"
    t.text "notes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "accountings", force: :cascade do |t|
    t.integer "property_id"
    t.string "r_e"
    t.string "description"
    t.decimal "amount"
    t.text "notes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.date "record_date"
  end

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
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "booking_days", force: :cascade do |t|
    t.date "day"
    t.integer "property_id"
    t.decimal "day_rate"
    t.string "extra_s"
    t.integer "extra_i"
    t.boolean "extra_b"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "bookings", force: :cascade do |t|
    t.integer "property_id"
    t.string "guest_name"
    t.string "platform"
    t.string "confirmation_code"
    t.date "check_in"
    t.date "check_out"
    t.integer "nights"
    t.decimal "payout"
    t.string "notes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "design_concepts", force: :cascade do |t|
    t.string "title", null: false
    t.string "kind", default: "other"
    t.string "status", default: "idea"
    t.string "location"
    t.string "summary"
    t.text "description"
    t.integer "position", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.jsonb "render_settings", default: {}, null: false
    t.index ["position"], name: "index_design_concepts_on_position"
  end

  create_table "design_floor_plans", force: :cascade do |t|
    t.bigint "concept_id", null: false
    t.string "name", null: false
    t.string "level"
    t.decimal "width_ft", precision: 7, scale: 2, default: "60.0", null: false
    t.decimal "depth_ft", precision: 7, scale: 2, default: "40.0", null: false
    t.jsonb "data", default: {}, null: false
    t.text "notes"
    t.integer "position", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["concept_id"], name: "index_design_floor_plans_on_concept_id"
    t.index ["position"], name: "index_design_floor_plans_on_position"
  end

  create_table "design_images", force: :cascade do |t|
    t.bigint "concept_id"
    t.string "title"
    t.text "caption"
    t.string "category", default: "inspiration"
    t.string "tags"
    t.string "source"
    t.integer "position", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["category"], name: "index_design_images_on_category"
    t.index ["concept_id"], name: "index_design_images_on_concept_id"
  end

  create_table "design_notes", force: :cascade do |t|
    t.bigint "concept_id"
    t.string "title"
    t.text "body", null: false
    t.string "tags"
    t.boolean "pinned", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["concept_id"], name: "index_design_notes_on_concept_id"
    t.index ["pinned"], name: "index_design_notes_on_pinned"
  end

  create_table "portfolio_documents", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "kind", default: "other"
    t.string "title", null: false
    t.date "issued_on"
    t.text "notes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["project_id"], name: "index_portfolio_documents_on_project_id"
  end

  create_table "portfolio_expenses", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "work_item_id"
    t.bigint "vendor_id"
    t.date "purchased_on"
    t.decimal "amount", precision: 12, scale: 2
    t.string "description"
    t.string "category", default: "materials"
    t.string "source"
    t.string "invoice_number"
    t.text "notes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["project_id"], name: "index_portfolio_expenses_on_project_id"
    t.index ["purchased_on"], name: "index_portfolio_expenses_on_purchased_on"
    t.index ["vendor_id"], name: "index_portfolio_expenses_on_vendor_id"
    t.index ["work_item_id"], name: "index_portfolio_expenses_on_work_item_id"
  end

  create_table "portfolio_photos", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "work_item_id"
    t.string "stage", default: "after"
    t.string "caption"
    t.date "taken_on"
    t.integer "position", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["project_id"], name: "index_portfolio_photos_on_project_id"
    t.index ["taken_on"], name: "index_portfolio_photos_on_taken_on"
    t.index ["work_item_id"], name: "index_portfolio_photos_on_work_item_id"
  end

  create_table "portfolio_projects", force: :cascade do |t|
    t.bigint "property_id", null: false
    t.string "title", null: false
    t.string "summary"
    t.text "description"
    t.date "started_on"
    t.date "completed_on"
    t.string "status", default: "completed"
    t.string "permit_number"
    t.text "permit_notes"
    t.text "notes"
    t.integer "position", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["property_id"], name: "index_portfolio_projects_on_property_id"
    t.index ["started_on"], name: "index_portfolio_projects_on_started_on"
  end

  create_table "portfolio_properties", force: :cascade do |t|
    t.string "name", null: false
    t.string "address"
    t.string "property_type"
    t.date "acquired_on"
    t.date "sold_on"
    t.string "status", default: "owned"
    t.text "notes"
    t.integer "position", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "portfolio_source_documents", force: :cascade do |t|
    t.string "source", null: false
    t.string "source_ref"
    t.date "occurred_on"
    t.string "vendor"
    t.string "title"
    t.text "description"
    t.string "property_guess"
    t.string "suggested_group"
    t.decimal "amount", precision: 12, scale: 2
    t.string "kind", default: "other"
    t.string "flags"
    t.string "status", default: "unreviewed"
    t.bigint "project_id"
    t.bigint "work_item_id"
    t.jsonb "metadata", default: {}
    t.text "notes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["occurred_on"], name: "index_portfolio_source_documents_on_occurred_on"
    t.index ["project_id"], name: "index_portfolio_source_documents_on_project_id"
    t.index ["source", "source_ref"], name: "index_portfolio_source_documents_on_source_and_source_ref", unique: true
    t.index ["source"], name: "index_portfolio_source_documents_on_source"
    t.index ["status"], name: "index_portfolio_source_documents_on_status"
    t.index ["work_item_id"], name: "index_portfolio_source_documents_on_work_item_id"
  end

  create_table "portfolio_vendors", force: :cascade do |t|
    t.string "name", null: false
    t.string "trade"
    t.string "contact_name"
    t.string "phone"
    t.string "email"
    t.string "website"
    t.string "license_number"
    t.text "notes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "portfolio_work_items", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "vendor_id"
    t.string "title", null: false
    t.string "trade"
    t.text "description"
    t.string "performed_by", default: "self"
    t.date "started_on"
    t.date "completed_on"
    t.decimal "hours", precision: 8, scale: 1
    t.text "notes"
    t.integer "position", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["project_id"], name: "index_portfolio_work_items_on_project_id"
    t.index ["vendor_id"], name: "index_portfolio_work_items_on_vendor_id"
  end

  create_table "properties", force: :cascade do |t|
    t.string "nickname"
    t.string "address"
    t.string "picture"
    t.decimal "bed"
    t.decimal "bath"
    t.integer "sq_ft"
    t.string "notes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "searches", force: :cascade do |t|
    t.string "property"
    t.string "accounting_type"
    t.string "description"
    t.date "date_range_a"
    t.date "date_range_b"
    t.string "field_1"
    t.string "field_2"
    t.string "field_3"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "remember_token", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["remember_token"], name: "index_users_on_remember_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "design_floor_plans", "design_concepts", column: "concept_id"
  add_foreign_key "design_images", "design_concepts", column: "concept_id"
  add_foreign_key "design_notes", "design_concepts", column: "concept_id"
  add_foreign_key "portfolio_documents", "portfolio_projects", column: "project_id"
  add_foreign_key "portfolio_expenses", "portfolio_projects", column: "project_id"
  add_foreign_key "portfolio_expenses", "portfolio_vendors", column: "vendor_id"
  add_foreign_key "portfolio_expenses", "portfolio_work_items", column: "work_item_id"
  add_foreign_key "portfolio_photos", "portfolio_projects", column: "project_id"
  add_foreign_key "portfolio_photos", "portfolio_work_items", column: "work_item_id"
  add_foreign_key "portfolio_projects", "portfolio_properties", column: "property_id"
  add_foreign_key "portfolio_source_documents", "portfolio_projects", column: "project_id"
  add_foreign_key "portfolio_source_documents", "portfolio_work_items", column: "work_item_id"
  add_foreign_key "portfolio_work_items", "portfolio_projects", column: "project_id"
  add_foreign_key "portfolio_work_items", "portfolio_vendors", column: "vendor_id"
end
