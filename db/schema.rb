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

ActiveRecord::Schema[8.1].define(version: 2026_04_23_210000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "default_pricings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "last_synced_at"
    t.string "pricing_key", null: false
    t.string "trade", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 10, scale: 2, null: false
    t.index ["trade", "pricing_key"], name: "index_default_pricings_on_trade_and_pricing_key", unique: true
    t.index ["trade"], name: "index_default_pricings_on_trade"
  end

  create_table "material_prices", force: :cascade do |t|
    t.string "category"
    t.string "confidence", default: "high"
    t.datetime "created_at", null: false
    t.datetime "fetched_at"
    t.string "name"
    t.decimal "previous_price", precision: 10, scale: 2
    t.decimal "price", precision: 10, scale: 2
    t.decimal "price_high", precision: 10, scale: 2
    t.decimal "price_low", precision: 10, scale: 2
    t.jsonb "raw_response", default: {}
    t.string "sku", null: false
    t.string "source", default: "bigbox"
    t.string "trade"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.string "zip_code", default: "national", null: false
    t.index ["category"], name: "index_material_prices_on_category"
    t.index ["fetched_at"], name: "index_material_prices_on_fetched_at"
    t.index ["sku", "zip_code"], name: "index_material_prices_on_sku_and_zip_code", unique: true
    t.index ["trade"], name: "index_material_prices_on_trade"
  end

  create_table "webhook_receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_summary"
    t.integer "payload_bytes", default: 0, null: false
    t.integer "products_failed", default: 0, null: false
    t.integer "products_received", default: 0, null: false
    t.integer "products_upserted", default: 0, null: false
    t.datetime "received_at", null: false
    t.string "remote_ip"
    t.string "source", default: "bigbox", null: false
    t.string "status", default: "success", null: false
    t.datetime "updated_at", null: false
    t.index ["received_at"], name: "index_webhook_receipts_on_received_at"
    t.index ["source"], name: "index_webhook_receipts_on_source"
    t.index ["status"], name: "index_webhook_receipts_on_status"
  end
end
