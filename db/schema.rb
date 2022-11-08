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

ActiveRecord::Schema.define(version: 2022_11_08_220813) do

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

end
