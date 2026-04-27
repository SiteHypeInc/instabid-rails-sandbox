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
#   BigboxDataLoaderService.load(zip_code: "98101")                   # all trades
#   BigboxDataLoaderService.load(trade: "roofing", zip_code: "98101") # one trade
#
# === DISABLED BY DEFAULT (TEA-157) ===
# This on-demand path was superseded by the BigBox Collections webhook pipeline
# (Webhooks::BigboxController + BigboxCollectionService). It leaked junk rows
# into `material_prices` (rows with price IS NULL and miscategorized trades —
# see admin /admin/material_prices, 2026-04-19) because it upserts the BigBox
# API's returned title under our own trade/category metadata even when no price
# is found.
#
# TEA-345: zip_code is now required — no "10001" default. The blessed writer
# (BigboxCollectionService) sources zips from ServiceAreaZip; if you're
# debugging through this service, pick one of those zips explicitly.
#
# The service now refuses to run unless ENV["ALLOW_BIGBOX_ONDEMAND"] == "true".
# When disabled it raises OnDemandDisabledError loudly so no rake task, console
# invocation, or admin endpoint can silently re-poison the table.
#
# To re-enable (only for one-off recon with John's explicit go-ahead):
#   ALLOW_BIGBOX_ONDEMAND=true bin/rails runner 'BigboxDataLoaderService.load(trade: "roofing", zip_code: "98101")'
#
# Long-term: prefer BigBox Collections (batch webhook) — it's the blessed writer.
class BigboxDataLoaderService
  SKUS_FILE       = Rails.root.join("db", "data", "material_skus.json")
  BIGBOX_BASE_URL = "https://api.bigboxapi.com/request"
  PER_REQUEST_PAUSE = 0.1   # seconds — stay well under BigBox rate limits

  # Raised when the on-demand path is invoked while disabled (default).
  class OnDemandDisabledError < RuntimeError; end

  LoadResult = Struct.new(
    :sku, :name, :trade, :category, :unit,
    :price, :status, :error,
    keyword_init: true
  )

  # True only when ENV["ALLOW_BIGBOX_ONDEMAND"] is explicitly set to "true".
  # Any other value (including unset, blank, "false", "0") keeps the path off.
  def self.enabled?
    ENV["ALLOW_BIGBOX_ONDEMAND"].to_s.strip.downcase == "true"
  end

  def self.load(trade: nil, zip_code:)
    ensure_enabled!
    new(trade: trade, zip_code: zip_code).load
  end

  def self.ensure_enabled!
    return if enabled?

    msg = "BigboxDataLoaderService is disabled. Set ALLOW_BIGBOX_ONDEMAND=true " \
          "to re-enable the on-demand API path. See TEA-157 / file header for why."
    Rails.logger.error("[BigboxDataLoader] #{msg}")
    raise OnDemandDisabledError, msg
  end

  def initialize(trade: nil, zip_code:)
    self.class.ensure_enabled!

    @trade_filter = trade&.to_s
    @zip_code     = zip_code.to_s

    raise ArgumentError, "zip_code is required" if @zip_code.blank?

    @api_key = ENV["BIGBOX_API_KEY"].to_s.strip
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

    product = fetch_product_by_id(sku)

    if product.nil?
      return LoadResult.new(
        sku: sku, name: item["name"], trade: trade,
        category: item["category"], unit: item["unit"],
        price: nil, status: "api_no_data",
        error: "BigBox returned no product for item_id '#{sku}'"
      )
    end

    price = extract_product_price(product)

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
      price: price, status: price ? "loaded" : "no_price"
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
  # Direct product page lookup by Home Depot item ID — more reliable than search.
  def fetch_product_by_id(item_id)
    uri       = URI(BIGBOX_BASE_URL)
    uri.query = URI.encode_www_form(
      api_key:          @api_key,
      type:             "product",
      item_id:          item_id,
      customer_zipcode: @zip_code
    )

    http             = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = true
    http.open_timeout = 15
    http.read_timeout = 60

    response = http.request(Net::HTTP::Get.new(uri.request_uri))

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("[BigboxDataLoader] HTTP #{response.code} for item_id '#{item_id}'")
      return nil
    end

    data = JSON.parse(response.body)

    unless data.dig("request_info", "success")
      msg = data.dig("request_info", "message") || "unknown error"
      Rails.logger.warn("[BigboxDataLoader] API error for item_id '#{item_id}': #{msg}")
      return nil
    end

    data["product"]

  rescue JSON::ParserError => e
    Rails.logger.error("[BigboxDataLoader] JSON parse error for item_id '#{item_id}': #{e.message}")
    nil
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[BigboxDataLoader] Timeout for item_id '#{item_id}': #{e.message}")
    nil
  rescue => e
    Rails.logger.error("[BigboxDataLoader] Network error for item_id '#{item_id}': #{e.message}")
    nil
  end

  # Extract price from a BigBox product response.
  # Product API returns price at buybox_winner.price.value or buybox_winner.price.raw.
  def extract_product_price(product)
    return nil unless product.is_a?(Hash)

    # Primary: buybox_winner.price.value (numeric)
    bb_price = product.dig("buybox_winner", "price", "value")
    return bb_price.to_d if bb_price.present? && bb_price.to_d > 0

    # Fallback: buybox_winner.price.raw ("$45.98")
    bb_raw = product.dig("buybox_winner", "price", "raw")
    if bb_raw.present?
      cleaned = bb_raw.to_s.gsub(/[^\d.]/, "")
      return cleaned.to_d if cleaned.present? && cleaned.to_d > 0
    end

    # Last resort: top-level price fields
    return product["price"].to_d if product["price"].present? && product["price"].to_d > 0

    nil
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
