class MaterialPrice < ApplicationRecord
  validates :sku, presence: true
  validates :zip_code, presence: true
  validates :sku, uniqueness: { scope: :zip_code }
  validates :price, numericality: { greater_than: 0 }, allow_nil: true

  CONFIDENCE_LEVELS = %w[high medium low].freeze

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
