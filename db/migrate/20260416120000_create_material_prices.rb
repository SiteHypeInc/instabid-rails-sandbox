class CreateMaterialPrices < ActiveRecord::Migration[8.1]
  def change
    create_table :material_prices do |t|
      t.string  :sku,            null: false
      t.string  :zip_code,       null: false, default: "national"
      t.string  :name
      t.string  :category
      t.string  :trade
      t.string  :unit
      t.decimal :price,          precision: 10, scale: 2
      t.decimal :previous_price, precision: 10, scale: 2
      t.string  :source,         default: "bigbox"
      t.string  :confidence,     default: "high"
      t.datetime :fetched_at
      t.jsonb   :raw_response,   default: {}

      t.timestamps null: false
    end

    add_index :material_prices, [ :sku, :zip_code ], unique: true
    add_index :material_prices, :trade
    add_index :material_prices, :fetched_at
    add_index :material_prices, :category
  end
end
