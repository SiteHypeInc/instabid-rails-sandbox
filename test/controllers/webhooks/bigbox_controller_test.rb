require "test_helper"

module Webhooks
  class BigboxControllerTest < ActionDispatch::IntegrationTest
    SECRET = "test-secret-abc123"

    setup do
      ENV["BIGBOX_WEBHOOK_SECRET"] = SECRET
    end

    teardown do
      ENV.delete("BIGBOX_WEBHOOK_SECRET")
      MaterialPrice.delete_all
      WebhookReceipt.delete_all
    end

    # ── Auth ────────────────────────────────────────────────────────────────

    test "rejects request with wrong secret" do
      post webhooks_bigbox_path,
           params: valid_payload.to_json,
           headers: auth_headers("wrong-secret")

      assert_response :unauthorized
    end

    test "rejects request with no secret" do
      post webhooks_bigbox_path,
           params: valid_payload.to_json,
           headers: { "Content-Type" => "application/json" }

      assert_response :unauthorized
    end

    test "returns 503 when BIGBOX_WEBHOOK_SECRET not configured" do
      ENV.delete("BIGBOX_WEBHOOK_SECRET")

      post webhooks_bigbox_path,
           params: valid_payload.to_json,
           headers: auth_headers(SECRET)

      assert_response :service_unavailable
    end

    # ── Happy path ───────────────────────────────────────────────────────────

    test "accepts valid payload and upserts products" do
      post webhooks_bigbox_path,
           params: valid_payload.to_json,
           headers: auth_headers(SECRET)

      assert_response :ok

      body = JSON.parse(response.body)
      assert_equal 2, body["received"]
      assert_equal 2, body["upserted"]
      assert_equal 0, body["failed"]
      assert_equal "success", body["status"]

      assert_equal 2, MaterialPrice.count
    end

    test "creates webhook receipt on success" do
      post webhooks_bigbox_path,
           params: valid_payload.to_json,
           headers: auth_headers(SECRET)

      receipt = WebhookReceipt.last
      assert_equal "bigbox", receipt.source
      assert_equal 2, receipt.products_received
      assert_equal 2, receipt.products_upserted
      assert_equal 0, receipt.products_failed
      assert_equal "success", receipt.status
    end

    test "accepts root-array payload format" do
      post webhooks_bigbox_path,
           params: valid_payload[:products].to_json,
           headers: auth_headers(SECRET)

      assert_response :ok
      assert_equal 2, MaterialPrice.count
    end

    # ── Upsert behaviour ────────────────────────────────────────────────────

    test "updates existing record and captures previous_price" do
      MaterialPrice.create!(sku: "SKU001", zip_code: "national",
                            price: 40.00, fetched_at: 1.week.ago)

      updated_payload = {
        products: [
          { sku: "SKU001", zip_code: "national", title: "Shingles Bundle",
            trade: "roofing", price: 44.99, unit: "bundle", fetched_at: Time.current.iso8601 }
        ]
      }

      post webhooks_bigbox_path,
           params: updated_payload.to_json,
           headers: auth_headers(SECRET)

      assert_response :ok

      record = MaterialPrice.find_by(sku: "SKU001", zip_code: "national")
      assert_equal 44.99, record.price.to_f
      assert_equal 40.00, record.previous_price.to_f
    end

    # ── Partial failure ──────────────────────────────────────────────────────

    test "partial failure: upserts valid products, logs failures, returns 200" do
      bad_product = { title: "No SKU here", price: 10.00 }  # missing sku
      good_product = valid_payload[:products].first

      mixed_payload = { products: [ bad_product, good_product ] }

      post webhooks_bigbox_path,
           params: mixed_payload.to_json,
           headers: auth_headers(SECRET)

      assert_response :ok

      body = JSON.parse(response.body)
      assert_equal 2, body["received"]
      assert_equal 1, body["upserted"]
      assert_equal 1, body["failed"]
      assert_equal "partial", body["status"]

      assert_equal 1, MaterialPrice.count

      receipt = WebhookReceipt.last
      assert_equal "partial", receipt.status
      assert receipt.error_summary.present?
    end

    # ── Error cases ──────────────────────────────────────────────────────────

    test "returns 422 for unparseable JSON" do
      post webhooks_bigbox_path,
           params: "not json at all!!!",
           headers: auth_headers(SECRET).merge("Content-Type" => "text/plain")

      assert_response :unprocessable_entity
    end

    test "returns 422 for empty products array" do
      post webhooks_bigbox_path,
           params: { products: [] }.to_json,
           headers: auth_headers(SECRET)

      assert_response :unprocessable_entity
    end

    private

    def auth_headers(secret)
      { "Content-Type" => "application/json", "X-Bigbox-Secret" => secret }
    end

    def valid_payload
      {
        products: [
          {
            sku: "SKU001",
            zip_code: "national",
            title: "Owens Corning Architectural Shingles",
            trade: "roofing",
            category: "shingles",
            unit: "bundle",
            price: 44.99,
            source: "bigbox",
            confidence: "high",
            fetched_at: Time.current.iso8601
          },
          {
            sku: "SKU002",
            zip_code: "national",
            title: "USG 1/2in Drywall Sheet 4x8",
            trade: "drywall",
            category: "drywall",
            unit: "sheet",
            price: 13.47,
            source: "bigbox",
            confidence: "high",
            fetched_at: Time.current.iso8601
          }
        ]
      }
    end
  end
end
