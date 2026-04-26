class MaterialPrice < ApplicationRecord
  validates :sku, presence: true
  validates :zip_code, presence: true
  validates :sku, uniqueness: { scope: :zip_code }
  validates :price, numericality: { greater_than: 0 }, allow_nil: true

  CONFIDENCE_LEVELS = %w[high medium low].freeze

  # Sources whose rows count as "live HD pricing" on the dashboard.
  # `sandbox_seed` is the Apr 17 hand-load of real HD SKUs/prices and
  # belongs in this cohort; the original sync only matched `bigbox*`,
  # which left 88 real-HD rows badging "Manual" on the dashboard.
  HD_LIVE_SOURCES = %w[bigbox bigbox_collection bigbox_hd sandbox_seed].freeze

  def self.hd_live_source?(source)
    HD_LIVE_SOURCES.include?(source.to_s)
  end

  scope :by_trade, ->(trade) { where(trade: trade) }
  scope :recent, -> { order(fetched_at: :desc) }
  scope :stale, ->(days = 14) { where("fetched_at < ?", days.days.ago) }

  def price_delta
    return nil unless previous_price.present? && price.present?

    price - previous_price
  end

  def price_delta_pct
    return nil unless price_delta && previous_price&.positive?

    ((price_delta / previous_price) * 100).round(1)
  end
end
