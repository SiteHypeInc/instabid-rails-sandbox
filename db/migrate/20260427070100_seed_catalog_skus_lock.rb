class SeedCatalogSkusLock < ActiveRecord::Migration[8.1]
  class CatalogSku < ActiveRecord::Base; end

  def up
    json_path = Rails.root.join("db", "data", "material_skus.json")
    raise "missing #{json_path}" unless File.exist?(json_path)

    data   = JSON.parse(File.read(json_path))
    locker = "todd:tea-340"
    locked = Time.current

    rows = data.flat_map do |trade, items|
      items.map do |item|
        sku = item.fetch("sku").to_s
        {
          trade:             trade,
          sku:               sku,
          name:              item.fetch("name"),
          category:          item["category"],
          unit:              item["unit"],
          bigbox_omsid:      sku,
          bigbox_url:        "https://www.homedepot.com/p/#{sku}",
          bigbox_locked_at:  locked,
          bigbox_locked_by:  locker,
          unavailable_at_hd: false,
          fallback_source:   nil,
          created_at:        locked,
          updated_at:        locked
        }
      end
    end

    # Dedup by sku — material_skus.json has at least one known duplicate
    # (plumbing sku 309237979). Keep first occurrence to satisfy the unique index.
    seen = {}
    rows.each { |r| seen[r[:sku]] ||= r }
    deduped = seen.values

    say_with_time "Seeding #{deduped.size} catalog_skus rows" do
      CatalogSku.reset_column_information
      CatalogSku.delete_all
      CatalogSku.insert_all(deduped)
    end
  end

  def down
    CatalogSku.reset_column_information if defined?(CatalogSku)
    execute "DELETE FROM catalog_skus"
  end
end
