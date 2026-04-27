class AddScrapeTrackingToCatalogSkus < ActiveRecord::Migration[8.1]
  def change
    change_table :catalog_skus do |t|
      t.datetime :last_scrape_at
      t.string   :last_scrape_status
      t.string   :last_scrape_failure_reason
      t.integer  :last_scrape_latency_ms
    end

    add_index :catalog_skus, :last_scrape_at
    add_index :catalog_skus, :last_scrape_status
  end
end
