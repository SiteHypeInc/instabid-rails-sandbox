class CatalogSku < ApplicationRecord
  validates :trade, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :name, presence: true

  scope :scrapable, -> { where(unavailable_at_hd: false) }
  scope :by_trade,  ->(trade) { where(trade: trade) }
  scope :stale,     ->(hours = 24) { where("last_scrape_at IS NULL OR last_scrape_at < ?", hours.hours.ago) }
end
