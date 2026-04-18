require "net/http"
require "json"

# Manages BigBox Collections for batch SKU price fetching.
#
# Architecture:
#   1. Create a collection with all 89 SKUs → BigBox queues async processing
#   2. BigBox runs the collection (triggered via UI or daily schedule)
#   3. GET /collections/{id}/results to ingest prices → material_prices
#   4. Optionally, BigBox fires a webhook when done (configure in BigBox UI)
#
# Usage:
#   id = BigboxCollectionService.create_production_collection
#   results = BigboxCollectionService.ingest_results(collection_id: id, zip_code: "10001")
#
class BigboxCollectionService
  BIGBOX_COLLECTIONS_URL = "https://api.bigboxapi.com/collections"
  SKUS_FILE              = Rails.root.join("db", "data", "material_skus.json")
  COLLECTION_NAME        = "instabid-materials-v1"

  IngestResult = Struct.new(
    :sku, :name, :trade, :category, :unit,
    :price, :status, :error,
    keyword_init: true
  )

  def self.create_production_collection(schedule: "daily", notify_email: "john@sitehypedesigns.com")
    new.create_collection(schedule: schedule, notify_email: notify_email)
  end

  def self.ingest_results(collection_id:, zip_code: "10001")
    new.ingest_results(collection_id: collection_id, zip_code: zip_code)
  end

  def initialize
    @api_key  = ENV["BIGBOX_API_KEY"].to_s.strip
    raise ArgumentError, "BIGBOX_API_KEY env var not set" if @api_key.blank?

    @skus_data = JSON.parse(File.read(SKUS_FILE))
  end

  # Creates (or recreates) the production collection with all 89 SKUs.
  # Returns collection_id string.
  def create_collection(schedule: "daily", notify_email: nil)
    requests = build_requests

    body = {
      name:          COLLECTION_NAME,
      schedule_type: schedule,
      requests:      requests
    }
    body[:notification_email] = notify_email if notify_email.present?

    uri       = URI(BIGBOX_COLLECTIONS_URL)
    uri.query = URI.encode_www_form(api_key: @api_key)

    req               = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json"
    req.body          = body.to_json

    response = build_http(uri).request(req)

    unless response.is_a?(Net::HTTPSuccess)
      raise "BigBox Collections create failed: HTTP #{response.code} — #{response.body[0, 300]}"
    end

    data       = JSON.parse(response.body)
    collection = data["collection"] || {}

    unless data.dig("request_info", "success")
      raise "BigBox Collections create error: #{data.dig("request_info", "message")}"
    end

    collection_id = collection["id"]
    Rails.logger.info("[BigboxCollection] Created collection #{collection_id} with #{requests.length} SKUs (schedule: #{schedule})")
    collection_id
  end

  # Fetches results from a completed collection and upserts into material_prices.
  # Returns array of IngestResult.
  def ingest_results(collection_id:, zip_code: "10001")
    @zip_code = zip_code.to_s

    uri       = URI("#{BIGBOX_COLLECTIONS_URL}/#{collection_id}/results")
    uri.query = URI.encode_www_form(api_key: @api_key)

    response = build_http(uri).request(Net::HTTP::Get.new(uri.request_uri))

    unless response.is_a?(Net::HTTPSuccess)
      raise "BigBox Collections results failed: HTTP #{response.code}"
    end

    data = JSON.parse(response.body)
    results_raw = Array(data["results"])

    Rails.logger.info("[BigboxCollection] #{collection_id}: #{results_raw.length} results found")

    if results_raw.empty?
      return [IngestResult.new(sku: nil, name: nil, trade: nil, category: nil,
                               unit: nil, price: nil, status: "no_results",
                               error: "Collection has 0 results — run may not have completed yet")]
    end

    # Build lookup: bigbox_item_id → our SKU metadata
    sku_lookup = build_sku_lookup

    results_raw.map { |row| ingest_one(row, sku_lookup) }

  rescue JSON::ParserError => e
    raise "BigBox Collections results parse error: #{e.message}"
  end

  # Lists all BigBox collections. Returns parsed JSON.
  def list_collections
    uri       = URI(BIGBOX_COLLECTIONS_URL)
    uri.query = URI.encode_www_form(api_key: @api_key)
    response  = build_http(uri).request(Net::HTTP::Get.new(uri.request_uri))
    JSON.parse(response.body)
  end

  private

  def build_requests
    @skus_data.flat_map do |_trade, items|
      items.map { |item| { type: "product", item_id: item["sku"].to_s } }
    end
  end

  # Map bigbox item_id → { sku:, name:, trade:, category:, unit: }
  def build_sku_lookup
    lookup = {}
    @skus_data.each do |trade, items|
      items.each do |item|
        lookup[item["sku"].to_s] = {
          sku:      item["sku"].to_s,
          name:     item["name"],
          trade:    trade.to_s,
          category: item["category"],
          unit:     item["unit"]
        }
      end
    end
    lookup
  end

  def ingest_one(row, sku_lookup)
    # BigBox Collections result shape:
    #   { "item_id": "202534215", "product": { "title": "...", ... }, "offers": { "primary": { "price": 42.97 } } }
    # OR flat:
    #   { "item_id": "202534215", "title": "...", "price": 42.97 }
    item_id = (row["item_id"] || row.dig("product", "item_id") || row.dig("product", "asin")).to_s
    meta    = sku_lookup[item_id]

    if meta.nil?
      Rails.logger.warn("[BigboxCollection] Unknown item_id #{item_id} — no matching SKU in material_skus.json")
      return IngestResult.new(
        sku: item_id, name: row.dig("product", "title"), trade: nil,
        category: nil, unit: nil, price: nil, status: "unknown_sku",
        error: "item_id #{item_id} not found in material_skus.json"
      )
    end

    product = row["product"] || row
    price   = extract_price(product, offers: row["offers"])

    if price.nil? || price <= 0
      return IngestResult.new(**meta, price: nil, status: "no_price",
                              error: "No valid price in result for #{item_id}")
    end

    upsert_material_price(
      sku:      meta[:sku],
      name:     product["title"].presence || meta[:name],
      category: meta[:category],
      trade:    meta[:trade],
      unit:     meta[:unit],
      price:    price
    )

    IngestResult.new(**meta, price: price, status: "loaded")

  rescue => e
    Rails.logger.error("[BigboxCollection] ingest_one #{item_id} failed: #{e.message}")
    IngestResult.new(**meta.to_h, price: nil, status: "error", error: e.message)
  end

  def extract_price(product, offers: nil)
    if offers.is_a?(Hash)
      offer_price = offers.dig("primary", "price")
      return offer_price.to_d if offer_price.present? && offer_price.to_d > 0
    end

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
      source:     "bigbox_collection",
      confidence: "high",
      fetched_at: Time.current
    )

    record.save!
  end

  def build_http(uri)
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = 12
    http.read_timeout = 12
    http
  end
end
