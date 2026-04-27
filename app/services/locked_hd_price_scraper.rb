require "net/http"
require "json"

# Per-SKU deterministic price fetch against the locked Home Depot product URL.
#
# TEA-341 — with TEA-340's catalog_skus.bigbox_url lock in place, every catalog
# row maps 1:1 to a Home Depot product page (homedepot.com/p/{sku}). This
# service does a single GET to the BigBox product API by item_id, parses the
# price, and returns a ScrapeResult so the caller (LockedPriceRefreshJob) can
# decide what to write into material_prices and how to record the attempt on
# the catalog row.
#
# Differs from BigboxDataLoaderService (disabled per TEA-157) in that it:
#   - takes a single CatalogSku, not a JSON-file walk
#   - never writes a junk row when no price is returned (caller upserts only on
#     success — failure is recorded on catalog_skus, not material_prices)
#   - returns timing so the job can report median latency
class LockedHdPriceScraper
  BIGBOX_BASE_URL  = "https://api.bigboxapi.com/request"
  OPEN_TIMEOUT_SEC = 12
  READ_TIMEOUT_SEC = 30

  ScrapeResult = Struct.new(
    :sku, :price, :price_low, :price_high, :title,
    :status, :error, :latency_ms,
    keyword_init: true
  )

  def self.scrape(catalog_sku, api_key: ENV["BIGBOX_API_KEY"].to_s.strip)
    new(api_key: api_key).scrape(catalog_sku)
  end

  def initialize(api_key:)
    raise ArgumentError, "BIGBOX_API_KEY env var not set" if api_key.blank?

    @api_key = api_key
  end

  def scrape(catalog_sku)
    started_at = monotonic_ms
    sku        = catalog_sku.sku.to_s

    response = bigbox_get(sku)
    latency  = (monotonic_ms - started_at).round

    return transient_result(sku, response, latency) unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    unless data.dig("request_info", "success")
      msg = data.dig("request_info", "message").to_s
      status = msg.match?(/not found/i) ? "not_found" : "transient"
      return ScrapeResult.new(sku: sku, status: status, error: msg.presence, latency_ms: latency)
    end

    product = data["product"] || {}
    title   = product["title"]
    price, low, high = extract_price_band(product, data["offers"])

    if price.nil?
      return ScrapeResult.new(
        sku: sku, title: title, status: "no_price",
        error: "Product returned but no usable price", latency_ms: latency
      )
    end

    ScrapeResult.new(
      sku:        sku,
      price:      price,
      price_low:  low,
      price_high: high,
      title:      title,
      status:     "success",
      latency_ms: latency
    )

  rescue JSON::ParserError => e
    ScrapeResult.new(sku: sku, status: "error", error: "json: #{e.message}", latency_ms: (monotonic_ms - started_at).round)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    ScrapeResult.new(sku: sku, status: "transient", error: "timeout: #{e.message}", latency_ms: (monotonic_ms - started_at).round)
  rescue => e
    ScrapeResult.new(sku: sku, status: "error", error: e.message, latency_ms: (monotonic_ms - started_at).round)
  end

  private

  def bigbox_get(item_id)
    uri       = URI(BIGBOX_BASE_URL)
    uri.query = URI.encode_www_form(api_key: @api_key, type: "product", item_id: item_id)

    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = OPEN_TIMEOUT_SEC
    http.read_timeout = READ_TIMEOUT_SEC
    http.request(Net::HTTP::Get.new(uri.request_uri))
  end

  def transient_result(sku, response, latency)
    body = response.respond_to?(:body) ? response.body.to_s[0, 200] : ""
    ScrapeResult.new(
      sku: sku, status: "transient",
      error: "HTTP #{response.code} #{body}", latency_ms: latency
    )
  end

  # Returns [price, price_low, price_high]. price = buybox winner; low/high
  # come from the price.range hash when BigBox returns one, else nil.
  def extract_price_band(product, offers)
    price = numeric_price(product.dig("buybox_winner", "price"))
    price ||= numeric_price(offers.is_a?(Hash) ? offers.dig("primary", "price") : nil)
    price ||= numeric_price(product["price"])

    range = product.dig("buybox_winner", "price", "range") if product.dig("buybox_winner", "price").is_a?(Hash)
    low   = numeric_price(range&.dig("min"))
    high  = numeric_price(range&.dig("max"))

    [price, low, high]
  end

  def numeric_price(value)
    case value
    when Numeric
      value.to_d.positive? ? value.to_d : nil
    when Hash
      from_value = value["value"]
      return from_value.to_d if from_value.present? && from_value.to_d.positive?

      raw = value["raw"]
      return nil if raw.blank?

      cleaned = raw.to_s.gsub(/[^\d.]/, "")
      cleaned.present? && cleaned.to_d.positive? ? cleaned.to_d : nil
    when String
      cleaned = value.gsub(/[^\d.]/, "")
      cleaned.present? && cleaned.to_d.positive? ? cleaned.to_d : nil
    end
  end

  def monotonic_ms
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
  end
end
