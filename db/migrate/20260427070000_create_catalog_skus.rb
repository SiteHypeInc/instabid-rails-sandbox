class CreateCatalogSkus < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_skus do |t|
      t.string  :trade,             null: false
      t.string  :sku,               null: false
      t.string  :name,              null: false
      t.string  :category
      t.string  :unit
      t.string  :bigbox_omsid
      t.string  :bigbox_url
      t.datetime :bigbox_locked_at
      t.string  :bigbox_locked_by
      t.boolean :unavailable_at_hd, null: false, default: false
      t.string  :fallback_source

      t.timestamps null: false
    end

    add_index :catalog_skus, :sku, unique: true
    add_index :catalog_skus, :trade
    add_index :catalog_skus, :bigbox_locked_at
  end
end
