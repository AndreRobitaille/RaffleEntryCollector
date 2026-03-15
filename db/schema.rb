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

ActiveRecord::Schema[8.1].define(version: 2026_03_15_171529) do
  create_table "entrants", force: :cascade do |t|
    t.string "company", null: false
    t.datetime "created_at", null: false
    t.boolean "eligibility_confirmed", default: false, null: false
    t.string "eligibility_status", default: "eligible", null: false
    t.string "email", null: false
    t.string "exclusion_reason"
    t.string "first_name", null: false
    t.json "interest_areas", default: []
    t.string "job_title", null: false
    t.string "last_name", null: false
    t.datetime "updated_at", null: false
    t.index ["eligibility_status"], name: "index_entrants_on_eligibility_status"
    t.index ["email"], name: "index_entrants_on_email"
    t.index ["first_name", "last_name", "company"], name: "index_entrants_on_first_name_and_last_name_and_company"
  end

  create_table "raffle_draws", force: :cascade do |t|
    t.text "admin_note"
    t.datetime "created_at", null: false
    t.string "draw_type", default: "winner", null: false
    t.integer "eligible_count", null: false
    t.datetime "updated_at", null: false
    t.integer "winner_id", null: false
    t.index ["winner_id"], name: "index_raffle_draws_on_winner_id"
  end

  add_foreign_key "raffle_draws", "entrants", column: "winner_id"
end
