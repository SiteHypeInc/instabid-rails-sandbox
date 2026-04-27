require "test_helper"

class BigboxCollectionServiceTest < ActiveSupport::TestCase
  def setup
    ENV["BIGBOX_API_KEY"] = "test_key"
    @service = BigboxCollectionService.new
  end

  def teardown
    ENV.delete("BIGBOX_API_KEY")
  end

  test "build_requests emits one request per (sku, service-area zip) with customer_zipcode" do
    requests = @service.send(:build_requests)

    sku_count = JSON.parse(File.read(BigboxCollectionService::SKUS_FILE))
                    .values.flatten.count
    expected_count = sku_count * ServiceAreaZip.codes.size

    assert_equal expected_count, requests.size,
      "expected one request per SKU × service-area zip"

    assert requests.all? { |r| r[:type] == "product" }, "all requests must be product type"
    assert requests.all? { |r| r[:item_id].present? },  "all requests must carry item_id"
    assert requests.all? { |r| ServiceAreaZip.codes.include?(r[:customer_zipcode]) },
      "every request must carry a service-area customer_zipcode"

    # Every distinct (sku, zip) pair must be covered. material_skus.json has
    # one cross-trade duplicate item_id, so we assert pair coverage rather
    # than "exactly one request per sku" (which would over-constrain on dupes).
    pairs = requests.map { |r| [r[:item_id], r[:customer_zipcode]] }.uniq
    expected_pairs = JSON.parse(File.read(BigboxCollectionService::SKUS_FILE))
                         .values.flatten.map { |i| i["sku"].to_s }.uniq
                         .product(ServiceAreaZip.codes)
    assert_equal expected_pairs.sort, pairs.sort,
      "every (sku, service-area zip) pair must be covered"
  end

  test "ingest_one writes MaterialPrice with zip_code from BigBox request echo" do
    sku_lookup = {
      "100016183" => {
        sku: "100016183", name: "Test Downspout", trade: "siding",
        category: "gutter_downspout", unit: "each"
      }
    }

    row = {
      "success" => true,
      "request" => { "item_id" => "100016183", "customer_zipcode" => "80202" },
      "result"  => {
        "product" => {
          "title" => "Live HD Title",
          "buybox_winner" => { "price" => { "value" => 49.99 } }
        }
      }
    }

    result = @service.send(:ingest_one, row, sku_lookup)
    assert_equal "loaded", result.status
    assert_equal "80202",  result.zip_code
    assert_equal 49.99.to_d, result.price

    record = MaterialPrice.find_by(sku: "100016183", zip_code: "80202")
    assert_not_nil record, "MaterialPrice row must be written under the request-echoed zip"
    assert_equal 49.99.to_d, record.price
    assert_equal "bigbox_collection", record.source
  end

  test "ingest_one returns no_zip status when customer_zipcode echo is missing" do
    sku_lookup = {
      "999" => { sku: "999", name: "x", trade: "siding", category: "x", unit: "each" }
    }
    row = {
      "success" => true,
      "request" => { "item_id" => "999" }, # no customer_zipcode
      "result"  => { "product" => { "buybox_winner" => { "price" => { "value" => 1.0 } } } }
    }

    result = @service.send(:ingest_one, row, sku_lookup)
    assert_equal "no_zip", result.status
    assert_nil result.zip_code
    assert_nil MaterialPrice.find_by(sku: "999")
  end

  test "ingest_one writes per-(sku,zip) rows so two zips for the same SKU coexist" do
    sku_lookup = {
      "203003641" => {
        sku: "203003641", name: "Roofing SKU", trade: "roofing",
        category: "shingles", unit: "bundle"
      }
    }

    @service.send(:ingest_one, {
      "success" => true,
      "request" => { "item_id" => "203003641", "customer_zipcode" => "98101" },
      "result"  => { "product" => { "buybox_winner" => { "price" => { "value" => 38.50 } } } }
    }, sku_lookup)

    @service.send(:ingest_one, {
      "success" => true,
      "request" => { "item_id" => "203003641", "customer_zipcode" => "30303" },
      "result"  => { "product" => { "buybox_winner" => { "price" => { "value" => 32.10 } } } }
    }, sku_lookup)

    rows = MaterialPrice.where(sku: "203003641").order(:zip_code)
    assert_equal 2, rows.size, "must write one row per (sku, zip)"
    assert_equal %w[30303 98101], rows.pluck(:zip_code).sort
    assert_not_equal rows.first.price, rows.last.price,
      "regional prices should differ once stored under their own zip"
  end
end
