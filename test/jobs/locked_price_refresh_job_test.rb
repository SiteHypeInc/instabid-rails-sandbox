require "test_helper"

class LockedPriceRefreshJobTest < ActiveSupport::TestCase
  def setup
    ENV["BIGBOX_API_KEY"] = "test_key"
    @job = LockedPriceRefreshJob.new
  end

  def teardown
    ENV.delete("BIGBOX_API_KEY")
  end

  test "raises when BIGBOX_API_KEY missing" do
    ENV.delete("BIGBOX_API_KEY")
    assert_raises(RuntimeError, /BIGBOX_API_KEY/) { @job.perform }
  end

  test "no-ops when no scrapable rows" do
    CatalogSku.stub :scrapable, CatalogSku.none do
      report = @job.perform
      assert_equal 0, report.attempted
    end
  end

  test "writes material_price on success and records latency" do
    sku  = build_catalog_sku(sku: "111")
    rows = FakeRelation.new([sku])

    fake_result = LockedHdPriceScraper::ScrapeResult.new(
      sku: "111", price: 10.0.to_d, price_low: 9.0.to_d, price_high: 11.0.to_d,
      title: "Widget", status: "success", latency_ms: 240
    )

    LockedHdPriceScraper.stub :new, ->(*) { stub_scraper(fake_result) } do
      CatalogSku.stub :scrapable, rows do
        @job.stub :sleep, nil do
          report = @job.perform
          assert_equal 1, report.attempted
          assert_equal 1, report.succeeded
          assert_equal 0, report.failed
          assert_equal 240, report.median_latency_ms
        end
      end
    end

    mp = MaterialPrice.find_by(sku: "111", zip_code: LockedPriceRefreshJob::ZIP_CODE)
    assert_not_nil mp
    assert_equal 10.0.to_d, mp.price
    assert_equal "homedepot", mp.source

    sku.reload
    assert_equal "success", sku.last_scrape_status
    assert_nil sku.last_scrape_failure_reason
  end

  test "records failure on catalog row without writing material_price" do
    sku  = build_catalog_sku(sku: "222")
    rows = FakeRelation.new([sku])

    fake_result = LockedHdPriceScraper::ScrapeResult.new(
      sku: "222", status: "not_found", error: "Product not found", latency_ms: 110
    )

    LockedHdPriceScraper.stub :new, ->(*) { stub_scraper(fake_result) } do
      CatalogSku.stub :scrapable, rows do
        @job.stub :sleep, nil do
          report = @job.perform
          assert_equal 1, report.attempted
          assert_equal 0, report.succeeded
          assert_equal 1, report.failed
          assert_equal 1, report.by_status["not_found"]
        end
      end
    end

    sku.reload
    assert_equal "not_found", sku.last_scrape_status
    assert_equal "Product not found", sku.last_scrape_failure_reason
    assert_nil MaterialPrice.find_by(sku: "222", zip_code: LockedPriceRefreshJob::ZIP_CODE)
  end

  test "computes median latency across mixed results" do
    rows_data = [
      [build_catalog_sku(sku: "a1"), 100, "success",   10.to_d],
      [build_catalog_sku(sku: "a2"), 200, "transient", nil],
      [build_catalog_sku(sku: "a3"), 300, "success",   20.to_d]
    ]
    rows = FakeRelation.new(rows_data.map(&:first))

    fake_results = rows_data.each_with_object({}) do |(s, lat, status, price), h|
      h[s.sku] = LockedHdPriceScraper::ScrapeResult.new(
        sku: s.sku, status: status, price: price, latency_ms: lat,
        error: status == "success" ? nil : "boom"
      )
    end

    scraper = Object.new
    scraper.define_singleton_method(:scrape) { |row| fake_results[row.sku] }

    LockedHdPriceScraper.stub :new, ->(*) { scraper } do
      CatalogSku.stub :scrapable, rows do
        @job.stub :sleep, nil do
          report = @job.perform
          assert_equal 3, report.attempted
          assert_equal 2, report.succeeded
          assert_equal 1, report.failed
          assert_equal 200, report.median_latency_ms
        end
      end
    end
  end

  private

  def build_catalog_sku(sku:)
    CatalogSku.create!(
      trade: "drywall", sku: sku, name: "Test #{sku}", category: "panel",
      unit: "sheet", bigbox_omsid: sku, bigbox_url: "https://www.homedepot.com/p/#{sku}",
      bigbox_locked_at: Time.current, bigbox_locked_by: "test", unavailable_at_hd: false
    )
  end

  def stub_scraper(result)
    s = Object.new
    s.define_singleton_method(:scrape) { |_row| result }
    s
  end

  # Minimal stand-in for an AR relation; provides find_each, size, empty?, order.
  class FakeRelation
    include Enumerable
    def initialize(rows); @rows = rows; end
    def each(&blk); @rows.each(&blk); end
    def find_each(batch_size: nil, &blk); @rows.each(&blk); end
    def size; @rows.size; end
    def empty?; @rows.empty?; end
    def order(*); self; end
  end
end
