# Daily price refresh over locked HD URLs.
#
# TEA-341 — iterates catalog_skus rows that are still flagged as available at
# Home Depot and refreshes material_prices for each one with a deterministic
# per-SKU GET against the locked product URL. Failures are recorded on the
# catalog row (last_scrape_status, last_scrape_failure_reason) so the
# multi-source fallback ticket (TEA-342) can re-route them later. The job
# does not raise on per-SKU failure — only a missing API key or a fully-empty
# catalog stops the run.
class LockedPriceRefreshJob < ApplicationJob
  queue_as :default

  PER_REQUEST_PAUSE = 0.1   # stay under BigBox rate limits
  ZIP_CODE          = "national"
  SOURCE_TAG        = "homedepot"

  RunReport = Struct.new(:attempted, :succeeded, :failed, :median_latency_ms, :by_status, keyword_init: true)

  def perform
    api_key = ENV["BIGBOX_API_KEY"].to_s.strip
    raise "BIGBOX_API_KEY not set" if api_key.blank?

    scraper = LockedHdPriceScraper.new(api_key: api_key)
    rows    = CatalogSku.scrapable.order(:trade, :sku)

    if rows.empty?
      log "No scrapable catalog_skus rows — nothing to refresh"
      return RunReport.new(attempted: 0, succeeded: 0, failed: 0, median_latency_ms: nil, by_status: {})
    end

    log "Refreshing #{rows.size} locked HD URLs"

    latencies = []
    by_status = Hash.new(0)
    started   = Time.current

    rows.find_each(batch_size: 100) do |sku_row|
      result = scraper.scrape(sku_row)
      latencies << result.latency_ms if result.latency_ms
      by_status[result.status] += 1

      if result.status == "success"
        upsert_material_price(sku_row, result)
      end

      record_attempt(sku_row, result)
      sleep PER_REQUEST_PAUSE
    end

    succeeded = by_status["success"]
    attempted = rows.size
    failed    = attempted - succeeded
    median    = median(latencies)

    log "Run complete in #{(Time.current - started).round(1)}s — " \
        "attempted=#{attempted} succeeded=#{succeeded} failed=#{failed} " \
        "median_latency_ms=#{median} by_status=#{by_status.to_h.inspect}"

    RunReport.new(
      attempted:         attempted,
      succeeded:         succeeded,
      failed:            failed,
      median_latency_ms: median,
      by_status:         by_status.to_h
    )
  end

  private

  def upsert_material_price(sku_row, result)
    record = MaterialPrice.find_or_initialize_by(sku: sku_row.sku, zip_code: ZIP_CODE)

    if record.persisted? && result.price && record.price != result.price
      record.previous_price = record.price
    end

    record.assign_attributes(
      name:       result.title.presence || sku_row.name,
      category:   sku_row.category,
      trade:      sku_row.trade,
      unit:       sku_row.unit,
      price:      result.price,
      price_low:  result.price_low,
      price_high: result.price_high,
      source:     SOURCE_TAG,
      confidence: "high",
      fetched_at: Time.current
    )

    record.save!
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[LockedPriceRefreshJob] upsert failed for #{sku_row.sku}: #{e.message}")
  end

  def record_attempt(sku_row, result)
    sku_row.update_columns(
      last_scrape_at:             Time.current,
      last_scrape_status:         result.status,
      last_scrape_failure_reason: result.status == "success" ? nil : result.error,
      last_scrape_latency_ms:     result.latency_ms,
      updated_at:                 Time.current
    )
  end

  def median(values)
    return nil if values.empty?

    sorted = values.sort
    mid    = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : ((sorted[mid - 1] + sorted[mid]) / 2.0).round
  end

  def log(msg)
    Rails.logger.info("[LockedPriceRefreshJob] #{msg}")
  end
end
