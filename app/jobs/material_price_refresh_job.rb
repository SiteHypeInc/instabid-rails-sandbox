require "net/http"
require "json"

# Daily scrape pipeline: start BigBox collection → poll for completion →
# ingest results into material_prices → sync default_pricings.
#
# Runs from config/recurring.yml. Single inline job so the whole pipeline
# either succeeds or surfaces a clear failure on one ticket.
#
# Hard rule (TEA-328): on rate limits / HD-side breakage / BigBox transient
# failure budget exceeded, raise and let the job fail loudly. Do not paper
# over with empty results.
class MaterialPriceRefreshJob < ApplicationJob
  queue_as :default

  # TEA-334: refreshed for plumbing SKU sweep (recreated with updated material_skus.json).
  COLLECTION_ID  = "FAD29CE5"
  ZIP_CODE       = "10001"
  POLL_INTERVAL  = 10.seconds
  POLL_TIMEOUT   = 8.minutes
  TRANSIENT_FAILURE_BUDGET = 0.40 # > 40% transient = stop and report

  BIGBOX_BASE = "https://api.bigboxapi.com/collections"

  def perform
    api_key = ENV["BIGBOX_API_KEY"].to_s.strip
    raise "BIGBOX_API_KEY not set" if api_key.blank?

    log "Starting BigBox collection #{COLLECTION_ID}"
    start_collection(api_key)

    log "Polling for completion (timeout: #{POLL_TIMEOUT.inspect})"
    wait_for_completion(api_key)

    log "Ingesting results into material_prices"
    ingest = BigboxCollectionService.ingest_results(collection_id: COLLECTION_ID, zip_code: ZIP_CODE)
    by_status = ingest.group_by(&:status).transform_values(&:count)
    log "Ingest summary: #{by_status.inspect}"

    transient_ratio = by_status.fetch("transient", 0).to_f / [ingest.size, 1].max
    if transient_ratio > TRANSIENT_FAILURE_BUDGET
      raise "BigBox transient failure ratio #{(transient_ratio * 100).round(1)}% exceeds budget — likely rate limit or HD-side break"
    end

    log "Running pricing sync"
    sync_results = MaterialPriceSyncService.sync
    changed = sync_results.count { |r| r.before_value && r.after_value && r.before_value != r.after_value }
    new_keys = sync_results.count { |r| r.before_value.nil? && r.after_value.present? }
    log "Sync done: #{sync_results.size} rows, #{changed} price changes, #{new_keys} newly populated keys"
  end

  private

  def start_collection(api_key)
    uri = URI("#{BIGBOX_BASE}/#{COLLECTION_ID}/start")
    uri.query = URI.encode_www_form(api_key: api_key)
    response = http(uri).request(Net::HTTP::Get.new(uri.request_uri))
    unless response.is_a?(Net::HTTPSuccess)
      raise "BigBox start failed: HTTP #{response.code} — #{response.body[0, 300]}"
    end
  end

  def wait_for_completion(api_key)
    deadline = Time.current + POLL_TIMEOUT
    initial_last_run = collection_last_run(api_key)

    loop do
      if Time.current > deadline
        raise "BigBox collection #{COLLECTION_ID} did not complete within #{POLL_TIMEOUT.inspect}"
      end

      sleep POLL_INTERVAL
      data = collection_data(api_key)
      status = data.dig("collection", "status")
      last_run = data.dig("collection", "last_run")

      if status == "idle" && last_run != initial_last_run
        log "Collection complete, last_run=#{last_run}"
        return
      end
    end
  end

  def collection_data(api_key)
    uri = URI("#{BIGBOX_BASE}/#{COLLECTION_ID}")
    uri.query = URI.encode_www_form(api_key: api_key)
    response = http(uri).request(Net::HTTP::Get.new(uri.request_uri))
    raise "BigBox collection fetch failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def collection_last_run(api_key)
    collection_data(api_key).dig("collection", "last_run")
  end

  def http(uri)
    h = Net::HTTP.new(uri.host, uri.port)
    h.use_ssl = true
    h.open_timeout = 12
    h.read_timeout = 30
    h
  end

  def log(msg)
    Rails.logger.info("[MaterialPriceRefreshJob] #{msg}")
  end
end
