require "net/http"
require "json"

# Loads HD product prices from BigBox API into material_prices.
#
# Reads db/data/material_skus.json, fetches each SKU from the BigBox product API,
# and upserts results into material_prices. Mirrors the upsert logic in
# Webhooks::BigboxController so data shape is identical whether it arrived
# via webhook or this loader.
#
# Usage (admin endpoint or console):
#   BigboxDataLoaderService.load                        # all trades
#   BigboxDataLoaderService.load(trade: "roofing")      # one trade
#   BigboxDataLoaderService.load(zip_code: "90210")     # regional pricing
#
class BigboxDataLoaderService
  SKUS_FILE       = Rails.root.join("db", "data", "material_skus.json")
  BIGBOX_BASE_URL = "https://api.bigboxapi.com/request"
  PER_REQUEST_PAUSE = 0.1   # seconds — stay well under BigBox rate limits

  LoadResult = Struct.new(
    :sku, :name, :trade, :category, :unit,
    :price, :status, :error,
    keyword_init: true
  )

  def self.load(trade: nil, zip_code: "10001")
    new(trade: trade, zip_code: zip_code).load
  end

  def initialize(trade: nil, zip_code: "10001")
    @trade_filter = trade&.to_s
    @zip_code     = zip_code.to_s
    @api_key      = ENV["BIGBOX_API_KEY"].to_s.strip

    raise ArgumentError, "BIGBOX_API_KEY env var not set" if @api_key.blank?

    @skus_data = JSON.parse(File.read(SKUS_FILE))
  end

  def load
    results = []

    @skus_data.each do |trade_name, items|
      next if @trade_filter.present? && @trade_filter != trade_name.to_s

      items.each do |item|
        results << load_one(trade: trade_name.to_s, item: item)
        sleep PER_REQUEST_PAUSE
      end
    end

    results
  end

  private

  def load_one(trade:, item:)
    sku = item["sku"].to_s

    product = fetch_from_bigbox(sku)

    if product.nil?
      return LoadResult.new(
        sku: sku, name: item["name"], trade: trade,
        category: item["category"], unit: item["unit"],
        price: nil, status: "api_no_data",
        error: "BigBox returned no product for SKU #{sku}"
      )
    end

    price = extract_price(product)

    upsert_material_price(
      sku:      sku,
      name:     product["title"].presence || item["name"],
      category: item["category"],
      trade:    trade,
      unit:     item["unit"],
      price:    price
    )

    LoadResult.new(
      sku: sku, name: item["name"], trade: trade,
      category: item["category"], unit: item["unit"],
      price: price, status: "loaded"
    )

  rescue => e
    Rails.logger.error("[BigboxDataLoader] #{trade}/#{sku} failed: #{e.message}")
    LoadResult.new(
      sku: sku, name: item["name"], trade: trade,
      category: item["category"], unit: item["unit"],
      price: nil, status: "error", error: e.message
    )
  end

  # BigBox product API: GET /request?api_key=KEY&type=product&item_id=SKU
  def fetch_from_bigbox(sku)
    uri       = URI(BIGBOX_BASE_URL)
    uri.query = URI.encode_www_form(api_key: @api_key, type: "product", item_id: sku)

    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("[BigboxDataLoader] HTTP #{response.code} for SKU #{sku}")
      return nil
    end

    data = JSON.parse(response.body)
    data["product"]

  rescue JSON::ParserError => e
    Rails.logger.error("[BigboxDataLoader] JSON parse error for SKU #{sku}: #{e.message}")
    nil
  rescue => e
    Rails.logger.error("[BigboxDataLoader] Network error for SKU #{sku}: #{e.message}")
    nil
  end

  # BigBox may return price as a float or as a "$45.98"-style string.
  def extract_price(product)
    return product["price"].to_d if product["price"].present?

    raw = product["price_string"] || product["price_raw"] || product["list_price"]
    return nil if raw.blank?

    cleaned = raw.to_s.gsub(/[^\d.]/, "")
    cleaned.present? ? cleaned.to_d : nil
  end

  def upsert_material_price(sku:, name:, category:, trade:, unit:, price:)
    record = MaterialPrice.find_or_initialize_by(sku: sku, zip_code: @zip_code)

    if record.persisted? && price && record.price != price
      record.previous_price = record.price
    end

    record.assign_attributes(
      name:       name,
      category:   category,
      trade:      trade,
      unit:       unit,
      price:      price,
      source:     "bigbox_loader",
      confidence: "high",
      fetched_at: Time.current
    )

    record.save!
  end
end
