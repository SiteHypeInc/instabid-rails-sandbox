class AddPriceRangeToMaterialPrices < ActiveRecord::Migration[8.1]
  def change
    change_table :material_prices do |t|
      t.decimal :price_low,  precision: 10, scale: 2
      t.decimal :price_high, precision: 10, scale: 2
    end
  end
end
