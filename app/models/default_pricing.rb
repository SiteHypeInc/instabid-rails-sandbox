class DefaultPricing < ApplicationRecord
  validates :trade,       presence: true
  validates :pricing_key, presence: true
  validates :value,       presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :pricing_key, uniqueness: { scope: :trade }

  scope :for_trade, ->(trade) { where(trade: trade) }
  scope :by_key,    ->(key)   { where(pricing_key: key) }
end
