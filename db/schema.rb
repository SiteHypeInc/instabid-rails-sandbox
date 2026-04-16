# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source of truth for your database schema. When creating the
# application database on another system, use db:schema:load, not running all
# migrations from scratch.
#
# It's strongly recommended that you check this file into version control.

ActiveRecord::Schema[8.1].define(version: 2026_04_16_120001) do
  enable_extension "pg_catalog.plpgsql"

  create_table "material_prices", force: :cascade do |t|
    t.string   "sku",            null: false
    t.string   "zip_code",       null: false, default: "national"
    t.string   "name"
    t.string   "category"
    t.string   "trade"
    t.string   "unit"
    t.decimal  "price",          precision: 10, scale: 2
    t.decimal  "previous_price", precision: 10, scale: 2
    t.string   "source",         default: "bigbox"
    t.string   "confidence",     default: "high"
    t.datetime "fetched_at"
    t.jsonb    "raw_response",   default: {}
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.index ["sku", "zip_code"],  name: "index_material_prices_on_sku_and_zip_code", unique: true
    t.index ["trade"],            name: "index_material_prices_on_trade"
    t.index ["fetched_at"],       name: "index_material_prices_on_fetched_at"
    t.index ["category"],         name: "index_material_prices_on_category"
  end

  create_table "webhook_receipts", force: :cascade do |t|
    t.string   "source",             null: false, default: "bigbox"
    t.integer  "products_received",  null: false, default: 0
    t.integer  "products_upserted",  null: false, default: 0
    t.integer  "products_failed",    null: false, default: 0
    t.integer  "payload_bytes",      null: false, default: 0
    t.string   "status",             null: false, default: "success"
    t.text     "error_summary"
    t.string   "remote_ip"
    t.datetime "received_at",        null: false
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.index ["source"],              name: "index_webhook_receipts_on_source"
    t.index ["received_at"],         name: "index_webhook_receipts_on_received_at"
    t.index ["status"],              name: "index_webhook_receipts_on_status"
  end
end
