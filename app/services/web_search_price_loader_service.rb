require "json"

# Loads the per-trade Road B review outputs (Tavily + OpenRouter/Haiku) into
# material_prices with source='web_search'.
#
# Source JSON: docs/tea-203/needs_review_<trade>.json
# Each row comes from scripts/tea203_road_b.py; the pipeline tags confidence
# and optionally extracts match_price. Rows without match_price are skipped
# (status='skipped_no_price') — the re-run with a price-targeted query should
# re-fill those before this loader can land them.
#
# sku in material_prices is always the pricing_key — same convention as the
# specialty loader. Using the HD item_id as the sku would collide with
# existing bigbox_collection rows (which use the item_id as sku), so
# web_search rows intentionally live in the pricing_key keyspace.
class WebSearchPriceLoaderService
  SOURCE_TAG = "web_search".freeze
  DOCS_DIR   = Rails.root.join("docs", "tea-203").freeze

  TRADE_TO_TRADE_LABEL = {
    "cabinets"   => "cabinets",
    "drywall"    => "drywall",
    "electrical" => "electrical",
    "flooring"   => "flooring",
    "hvac"       => "hvac",
    "painting"   => "painting",
    "plumbing"   => "plumbing",
    "roofing"    => "roofing",
    "siding"     => "siding"
  }.freeze

  LoadResult = Struct.new(
    :pricing_key, :trade, :sku, :price, :confidence,
    :status, :error,
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

    TRADE_TO_TRADE_LABEL.each do |file_key, trade|
      path = DOCS_DIR.join("needs_review_#{file_key}.json")
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
    price       = row["match_price"]
    confidence  = row["confidence"].presence
    item_id     = row["item_id"].presence

    if pricing_key.blank?
      return LoadResult.new(pricing_key: pricing_key, trade: trade,
                            status: "skipped_incomplete",
                            error: "row missing pricing_key")
    end

    if price.blank? || confidence.nil? || !%w[high medium low].include?(confidence)
      return LoadResult.new(pricing_key: pricing_key, trade: trade,
                            price: price, confidence: confidence,
                            status: "skipped_no_price",
                            error: "missing match_price or non-usable confidence")
    end

    sku     = pricing_key
    record  = MaterialPrice.find_or_initialize_by(sku: sku, zip_code: @zip_code)

    if record.persisted? && record.price != price.to_d
      record.previous_price = record.price
    end

    record.assign_attributes(
      name:         row["match_title"].presence || row["item_name"].presence || pricing_key.humanize,
      category:     row["type"],
      trade:        trade,
      unit:         row["price_unit"].presence || row["unit"],
      price:        price,
      source:       SOURCE_TAG,
      confidence:   confidence,
      fetched_at:   Time.current,
      raw_response: {
        "pricing_key"   => pricing_key,
        "item_id"       => item_id,
        "hd_url"        => row["hd_url"],
        "search_query"  => row["search_query"],
        "haiku_reason"  => row["haiku_reason"],
        "haiku_matches" => row["haiku_matches"]
      }
    )

    was_new = record.new_record?
    record.save!

    LoadResult.new(
      pricing_key: pricing_key, trade: trade, sku: sku,
      price: price, confidence: confidence,
      status: was_new ? "created" : "updated"
    )

  rescue => e
    LoadResult.new(
      pricing_key: pricing_key, trade: trade,
      price: price, confidence: confidence,
      status: "error", error: e.message
    )
  end
end
