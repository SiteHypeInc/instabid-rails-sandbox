class CreateDefaultPricings < ActiveRecord::Migration[8.1]
  def change
    create_table :default_pricings do |t|
      t.string  :trade,          null: false
      t.string  :pricing_key,    null: false
      t.string  :description
      t.decimal :value,          precision: 10, scale: 2, null: false
      t.datetime :last_synced_at
      t.timestamps null: false
    end

    add_index :default_pricings, [ :trade, :pricing_key ], unique: true
    add_index :default_pricings, :trade
  end
end
