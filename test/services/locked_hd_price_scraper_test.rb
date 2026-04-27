require "test_helper"
require "ostruct"

class LockedHdPriceScraperTest < ActiveSupport::TestCase
  def setup
    @row = OpenStruct.new(sku: "300147687")
  end

  test "raises without API key" do
    assert_raises(ArgumentError) { LockedHdPriceScraper.new(api_key: "") }
  end

  test "returns success with price from buybox numeric" do
    body = {
      "request_info" => { "success" => true },
      "product"      => {
        "title"          => "Some Product",
        "buybox_winner"  => { "price" => 51.23 }
      }
    }.to_json

    scraper = LockedHdPriceScraper.new(api_key: "k")
    scraper.stub :bigbox_get, http_ok(body) do
      result = scraper.scrape(@row)
      assert_equal "success", result.status
      assert_equal "300147687", result.sku
      assert_equal 51.23.to_d, result.price
      assert_equal "Some Product", result.title
      assert result.latency_ms.to_i >= 0
    end
  end

  test "extracts price.value, range, and offers fallback" do
    body = {
      "request_info" => { "success" => true },
      "product"      => {
        "buybox_winner" => {
          "price" => { "value" => 12.5, "range" => { "min" => 10.0, "max" => 15.0 } }
        }
      }
    }.to_json

    scraper = LockedHdPriceScraper.new(api_key: "k")
    scraper.stub :bigbox_get, http_ok(body) do
      result = scraper.scrape(@row)
      assert_equal "success", result.status
      assert_equal 12.5.to_d, result.price
      assert_equal 10.0.to_d, result.price_low
      assert_equal 15.0.to_d, result.price_high
    end
  end

  test "marks not_found when BigBox reports product not found" do
    body = {
      "request_info" => { "success" => false, "message" => "Product not found" }
    }.to_json

    scraper = LockedHdPriceScraper.new(api_key: "k")
    scraper.stub :bigbox_get, http_ok(body) do
      result = scraper.scrape(@row)
      assert_equal "not_found", result.status
      assert_equal "Product not found", result.error
    end
  end

  test "marks transient on non-2xx after exhausting retries" do
    scraper = LockedHdPriceScraper.new(api_key: "k")
    scraper.stub :sleep, nil do
      scraper.stub :bigbox_get, http_5xx("503", "upstream busy") do
        result = scraper.scrape(@row)
        assert_equal "transient", result.status
        assert_match(/HTTP 503/, result.error)
        assert_equal LockedHdPriceScraper::MAX_ATTEMPTS, result.attempts
      end
    end
  end

  test "retries on transient 5xx and succeeds on later attempt" do
    success_body = {
      "request_info" => { "success" => true },
      "product"      => { "title" => "x", "buybox_winner" => { "price" => 9.99 } }
    }.to_json
    responses = [
      http_5xx("502", "bad gateway"),
      http_5xx("503", "still busy"),
      http_ok(success_body)
    ]

    scraper = LockedHdPriceScraper.new(api_key: "k")
    scraper.define_singleton_method(:bigbox_get) { |_id| responses.shift }
    scraper.stub :sleep, nil do
      result = scraper.scrape(@row)
      assert_equal "success", result.status
      assert_equal 3, result.attempts
      assert_equal 9.99.to_d, result.price
    end
  end

  test "does not retry on 4xx" do
    calls = 0
    scraper = LockedHdPriceScraper.new(api_key: "k")
    scraper.define_singleton_method(:bigbox_get) do |_id|
      calls += 1
      fake = OpenStruct.new(code: "404", body: "not found")
      def fake.is_a?(klass); klass == Net::HTTPSuccess ? false : super; end
      fake
    end
    scraper.stub :sleep, nil do
      result = scraper.scrape(@row)
      assert_equal "transient", result.status
      assert_equal 1, calls
      assert_equal 1, result.attempts
    end
  end

  test "retries on connection timeout and surfaces transient on exhaustion" do
    scraper = LockedHdPriceScraper.new(api_key: "k")
    scraper.define_singleton_method(:bigbox_get) { |_id| raise Net::OpenTimeout, "boom" }
    scraper.stub :sleep, nil do
      result = scraper.scrape(@row)
      assert_equal "transient", result.status
      assert_match(/timeout/, result.error)
    end
  end

  test "marks no_price when product has no usable price" do
    body = {
      "request_info" => { "success" => true },
      "product"      => { "title" => "x", "buybox_winner" => { "price" => 0 } }
    }.to_json

    scraper = LockedHdPriceScraper.new(api_key: "k")
    scraper.stub :bigbox_get, http_ok(body) do
      result = scraper.scrape(@row)
      assert_equal "no_price", result.status
    end
  end

  test "marks error on JSON parse failure" do
    scraper = LockedHdPriceScraper.new(api_key: "k")
    scraper.stub :bigbox_get, http_ok("not json") do
      result = scraper.scrape(@row)
      assert_equal "error", result.status
      assert_match(/json/, result.error)
    end
  end

  private

  def http_ok(body)
    fake = OpenStruct.new(code: "200", body: body)
    def fake.is_a?(klass); klass == Net::HTTPSuccess ? true : super; end
    fake
  end

  def http_5xx(code, body)
    fake = OpenStruct.new(code: code, body: body)
    def fake.is_a?(klass); klass == Net::HTTPSuccess ? false : super; end
    fake
  end
end
