require "net/http"
require "json"

# Manages BigBox Collections for batch SKU price fetching.
#
# Architecture:
#   1. Create a collection with all SKUs × N service-area zips → BigBox queues async processing
#   2. BigBox runs the collection (triggered via UI or daily schedule)
#   3. GET /collections/{id}/results to ingest prices → material_prices
#   4. Optionally, BigBox fires a webhook when done (configure in BigBox UI)
#
# TEA-345: each request carries a `customer_zipcode` so HD returns regional
# pricing per zip. Ingest reads that echo back from `row["request"]` and
# writes one MaterialPrice per (sku, zip_code).
#
# Usage:
#   id = BigboxCollectionService.create_production_collection
#   results = BigboxCollectionService.ingest_results(collection_id: id)
#
class BigboxCollectionService
  BIGBOX_COLLECTIONS_URL = "https://api.bigboxapi.com/collections"
  SKUS_FILE              = Rails.root.join("db", "data", "material_skus.json")
  COLLECTION_NAME        = "instabid-materials-v1"

  IngestResult = Struct.new(
    :sku, :name, :trade, :category, :unit, :zip_code,
    :price, :status, :error,
    keyword_init: true
  )

  def self.create_production_collection(schedule: "manual", notify_email: "john@sitehypedesigns.com")
    new.create_collection(schedule: schedule, notify_email: notify_email)
  end

  def self.ingest_results(collection_id:)
    new.ingest_results(collection_id: collection_id)
  end

  def initialize
    @api_key  = ENV["BIGBOX_API_KEY"].to_s.strip
    raise ArgumentError, "BIGBOX_API_KEY env var not set" if @api_key.blank?

    @skus_data = JSON.parse(File.read(SKUS_FILE))
  end

  # Creates (or recreates) the production collection with all SKUs × all
  # service-area zips. Returns collection_id string.
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
    Rails.logger.info("[BigboxCollection] Created collection #{collection_id} with #{requests.length} requests across #{ServiceAreaZip.codes.length} zip(s) (schedule: #{schedule})")
    collection_id
  end

  # Fetches results from a completed collection and upserts into material_prices.
  # Returns array of IngestResult.
  #
  # Each row's zip_code is taken from the request echo
  # (`row["request"]["customer_zipcode"]`); the collection MUST have been
  # built via build_requests so per-zip echoes are present.
  def ingest_results(collection_id:)
    set_ids = list_result_set_ids(collection_id)

    if set_ids.empty?
      return [IngestResult.new(sku: nil, name: nil, trade: nil, category: nil,
                               unit: nil, zip_code: nil, price: nil, status: "no_results",
                               error: "Collection has 0 result sets — run may not have completed yet")]
    end

    sku_lookup = build_sku_lookup
    by_pair    = {} # [sku, zip_code] → latest IngestResult (later sets overwrite earlier)

    set_ids.each do |set_id|
      page_urls = fetch_page_urls(collection_id: collection_id, set_id: set_id)
      Rails.logger.info("[BigboxCollection] #{collection_id} set #{set_id}: #{page_urls.length} page(s)")

      page_urls.each do |url|
        rows = fetch_page_rows(url)
        Rails.logger.info("[BigboxCollection] page #{url.split('/').last}: #{rows.length} rows")
        rows.each do |row|
          result = ingest_one(row, sku_lookup)
          key    = [result.sku.presence || SecureRandom.hex(4), result.zip_code.to_s]
          by_pair[key] = result
        end
      end
    end

    by_pair.values

  rescue JSON::ParserError => e
    raise "BigBox Collections results parse error: #{e.message}"
  end

  def list_result_set_ids(collection_id)
    uri       = URI("#{BIGBOX_COLLECTIONS_URL}/#{collection_id}/results")
    uri.query = URI.encode_www_form(api_key: @api_key)
    response  = build_http(uri).request(Net::HTTP::Get.new(uri.request_uri))
    raise "BigBox Collections results failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    Array(JSON.parse(response.body)["results"]).map { |s| s["id"].to_s }.reject(&:blank?)
  end

  def fetch_page_urls(collection_id:, set_id:)
    uri       = URI("#{BIGBOX_COLLECTIONS_URL}/#{collection_id}/results/#{set_id}")
    uri.query = URI.encode_www_form(api_key: @api_key)
    response  = build_http(uri).request(Net::HTTP::Get.new(uri.request_uri))
    raise "BigBox result set fetch failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    Array(JSON.parse(response.body).dig("result", "download_links", "pages"))
  end

  def fetch_page_rows(url)
    uri      = URI(url)
    http     = build_http(uri)
    http.read_timeout = 60
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    raise "BigBox page download failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    Array(JSON.parse(response.body))
  end

  # Lists all BigBox collections. Returns parsed JSON.
  def list_collections
    uri       = URI(BIGBOX_COLLECTIONS_URL)
    uri.query = URI.encode_www_form(api_key: @api_key)
    response  = build_http(uri).request(Net::HTTP::Get.new(uri.request_uri))
    JSON.parse(response.body)
  end

  private

  # Build N×M product requests: every SKU × every service-area zip. The
  # `customer_zipcode` param tells BigBox which HD store to source from.
  def build_requests
    zips = ServiceAreaZip.codes
    raise "ServiceAreaZip is empty — config/service_area_zips.yml missing entries?" if zips.empty?

    @skus_data.flat_map do |_trade, items|
      items.flat_map do |item|
        zips.map do |zip|
          {
            type:             "product",
            item_id:          item["sku"].to_s,
            customer_zipcode: zip
          }
        end
      end
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

  # row shape: { success:, id:, result: { product?, offers?, message? },
  #              request: { item_id, customer_zipcode } }
  def ingest_one(row, sku_lookup)
    item_id  = row.dig("request", "item_id").to_s
    zip_code = row.dig("request", "customer_zipcode").to_s
    meta     = sku_lookup[item_id]

    if meta.nil?
      Rails.logger.warn("[BigboxCollection] Unknown item_id #{item_id} — no matching SKU in material_skus.json")
      return IngestResult.new(
        sku: item_id, name: nil, trade: nil, category: nil, unit: nil, zip_code: zip_code,
        price: nil, status: "unknown_sku", error: "item_id #{item_id} not found in material_skus.json"
      )
    end

    if zip_code.blank?
      Rails.logger.warn("[BigboxCollection] Row missing customer_zipcode echo for item_id #{item_id} — collection was built without per-zip requests; rebuild via create_production_collection")
      return IngestResult.new(**meta, zip_code: nil, price: nil, status: "no_zip",
                              error: "BigBox row had no customer_zipcode echo (rebuild collection)")
    end

    result_body = row["result"] || {}
    product     = result_body["product"]

    # "Product not found" — stale item_id, will not resolve on retry.
    if product.blank?
      message = result_body["message"].presence
      success = row["success"]
      status  = if message.to_s.match?(/not found/i)
                  "not_found"
                elsif success == false
                  "transient"
                else
                  "no_product"
                end
      return IngestResult.new(**meta, zip_code: zip_code, price: nil, status: status, error: message)
    end

    price = extract_price(product, offers: result_body["offers"])

    if price.nil? || price <= 0
      return IngestResult.new(**meta, zip_code: zip_code, price: nil, status: "no_price",
                              error: "Product returned but no usable price (#{item_id} @ #{zip_code})")
    end

    upsert_material_price(
      sku:      meta[:sku],
      zip_code: zip_code,
      name:     product["title"].presence || meta[:name],
      category: meta[:category],
      trade:    meta[:trade],
      unit:     meta[:unit],
      price:    price
    )

    IngestResult.new(**meta, zip_code: zip_code, price: price, status: "loaded")

  rescue => e
    Rails.logger.error("[BigboxCollection] ingest_one #{item_id.inspect}@#{zip_code.inspect} failed: #{e.message}")
    IngestResult.new(**(meta || {}).to_h, zip_code: zip_code.presence, price: nil, status: "error", error: e.message)
  end

  # Price precedence for BigBox Collections product results:
  #   1. product.buybox_winner.price (flat number, e.g. 51.23)
  #   2. product.buybox_winner.price.value (nested — older/alt shape)
  #   3. product.buybox_winner.price.raw  ("$45.98")
  #   4. offers.primary.price
  #   5. product.price / price_string / price_raw / list_price
  def extract_price(product, offers: nil)
    bb_price = product.dig("buybox_winner", "price")
    if bb_price.is_a?(Numeric)
      return bb_price.to_d if bb_price.to_d > 0
    elsif bb_price.is_a?(Hash)
      value = bb_price["value"]
      return value.to_d if value.present? && value.to_d > 0

      raw = bb_price["raw"]
      if raw.present?
        cleaned = raw.to_s.gsub(/[^\d.]/, "")
        return cleaned.to_d if cleaned.present? && cleaned.to_d > 0
      end
    end

    if offers.is_a?(Hash)
      offer_price = offers.dig("primary", "price")
      return offer_price.to_d if offer_price.present? && offer_price.to_d > 0
    end

    return product["price"].to_d if product["price"].present? && product["price"].to_d > 0

    raw = product["price_string"] || product["price_raw"] || product["list_price"]
    return nil if raw.blank?

    cleaned = raw.to_s.gsub(/[^\d.]/, "")
    cleaned.present? && cleaned.to_d > 0 ? cleaned.to_d : nil
  end

  def upsert_material_price(sku:, zip_code:, name:, category:, trade:, unit:, price:)
    record = MaterialPrice.find_or_initialize_by(sku: sku, zip_code: zip_code)

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
