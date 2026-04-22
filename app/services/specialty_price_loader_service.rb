require "json"

# Loads the 41 specialty gap-list rows (TEA-213) into material_prices.
#
# These rows have no Home Depot item_id and cannot flow through the BigBox
# Collections pipeline. Each row has a researched low/high range and a
# confidence tag.
#
# Source JSON: docs/tea-203/specialty_ranges_<trade>.json
# Sku used in material_prices is the pricing_key (e.g. "plumb_ball_valve_half"),
# not an HD item_id. source = "web_search_range" distinguishes these from
# bigbox_collection rows.
class SpecialtyPriceLoaderService
  SOURCE_TAG = "web_search_range".freeze
  DOCS_DIR   = Rails.root.join("docs", "tea-203").freeze

  TRADES = %w[cabinets drywall electrical hvac painting plumbing roofing siding].freeze

  LoadResult = Struct.new(
    :pricing_key, :trade, :unit, :price_low, :price_high,
    :confidence, :status, :error,
    keyword_init: true
  )

  def self.load(zip_code: "national")
    new(zip_code: zip_code).load
  end

  def initialize(zip_code: "national")
    @zip_code = zip_code.to_s
  end

  def load
    results = []

    TRADES.each do |trade|
      path = DOCS_DIR.join("specialty_ranges_#{trade}.json")
      next unless File.exist?(path)

      rows = JSON.parse(File.read(path))
      rows.each do |row|
        results << upsert_row(trade: trade, row: row)
      end
    end

    results
  end

  private

  def upsert_row(trade:, row:)
    pricing_key = row["pricing_key"].to_s
    price_low   = row["price_low"]
    price_high  = row["price_high"]
    confidence  = row["confidence"].presence || "medium"
    unit        = row["unit"]

    if pricing_key.blank? || price_low.blank? || price_high.blank?
      return LoadResult.new(
        pricing_key: pricing_key, trade: trade, unit: unit,
        price_low: price_low, price_high: price_high,
        confidence: confidence, status: "skipped_incomplete",
        error: "row missing pricing_key / price_low / price_high"
      )
    end

    midpoint = ((price_low.to_d + price_high.to_d) / 2).round(2)

    record  = MaterialPrice.find_or_initialize_by(sku: pricing_key, zip_code: @zip_code)
    was_new = record.new_record?

    if record.persisted? && record.price != midpoint
      record.previous_price = record.price
    end

    record.assign_attributes(
      name:         row["item_name"].presence || pricing_key.humanize,
      category:     row["type"], # INSTALLED / MATERIAL
      trade:        trade,
      unit:         unit,
      price:        midpoint,
      price_low:    price_low,
      price_high:   price_high,
      source:       SOURCE_TAG,
      confidence:   confidence,
      fetched_at:   Time.current,
      raw_response: {
        "filled_by" => row["filled_by"],
        "filled_at" => row["filled_at"],
        "notes"     => row["notes"],
        "source"    => row["source"] # research_suggested / etc.
      }
    )

    record.save!

    LoadResult.new(
      pricing_key: pricing_key, trade: trade, unit: unit,
      price_low: price_low, price_high: price_high,
      confidence: confidence, status: was_new ? "created" : "updated"
    )

  rescue => e
    LoadResult.new(
      pricing_key: pricing_key, trade: trade, unit: unit,
      price_low: price_low, price_high: price_high,
      confidence: confidence, status: "error", error: e.message
    )
  end
end
