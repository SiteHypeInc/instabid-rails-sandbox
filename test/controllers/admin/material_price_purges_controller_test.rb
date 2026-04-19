require "test_helper"

module Admin
  class MaterialPricePurgesControllerTest < ActionDispatch::IntegrationTest
    # TEA-164 — HTTP mirror of bigbox:purge_junk_rows. Fingerprint:
    # source = "bigbox_loader" AND price IS NULL. Dry-run unless confirm=yes.

    setup do
      # Three junk rows (bigbox_loader + nil price). These should be purged
      # when confirm=yes is passed and listed on every dry-run.
      @junk1 = MaterialPrice.create!(
        sku: "202532598", zip_code: "10001", trade: "hvac",
        name: "4068 Bi-fold Door", source: "bigbox_loader", price: nil
      )
      @junk2 = MaterialPrice.create!(
        sku: "100212074", zip_code: "10001", trade: "electrical",
        name: "Ceramic Cabinet Knob", source: "bigbox_loader", price: nil
      )
      @junk3 = MaterialPrice.create!(
        sku: "203003641", zip_code: "10001", trade: "roofing",
        name: "Fakro FX301L Skylight", source: "bigbox_loader", price: nil
      )

      # A bigbox_loader row WITH a price — must not be purged.
      @priced_loader_row = MaterialPrice.create!(
        sku: "999999999", zip_code: "10001", trade: "plumbing",
        name: "Priced loader row", source: "bigbox_loader", price: 12.34
      )

      # A nil-price row from a DIFFERENT source — must not be purged.
      @other_source_row = MaterialPrice.create!(
        sku: "888888888", zip_code: "10001", trade: "plumbing",
        name: "Other source nil-price row", source: "bigbox", price: nil
      )
    end

    test "dry run by default — lists junk rows without deleting" do
      assert_no_difference -> { MaterialPrice.count } do
        post admin_purge_junk_material_prices_path
      end

      assert_response :success
      body = JSON.parse(response.body)

      assert_equal "dry_run", body["status"]
      assert_equal true, body["dry_run"]
      assert_equal 3, body["count"]
      assert_equal 3, body["rows"].size
      assert_match(/confirm=yes/i, body["hint"])

      skus = body["rows"].map { |r| r["sku"] }
      assert_includes skus, "202532598"
      assert_includes skus, "100212074"
      assert_includes skus, "203003641"
      assert_not_includes skus, "999999999" # priced loader row
      assert_not_includes skus, "888888888" # other source row
    end

    test "confirm=yes actually deletes the junk rows" do
      assert_difference -> { MaterialPrice.count }, -3 do
        post admin_purge_junk_material_prices_path, params: { confirm: "yes" }
      end

      assert_response :success
      body = JSON.parse(response.body)

      assert_equal "purged", body["status"]
      assert_equal false, body["dry_run"]
      assert_equal 3, body["deleted"]
      assert_equal 0, body["remaining"]

      assert_nil MaterialPrice.find_by(id: @junk1.id)
      assert_nil MaterialPrice.find_by(id: @junk2.id)
      assert_nil MaterialPrice.find_by(id: @junk3.id)

      # Non-junk rows must survive.
      assert MaterialPrice.exists?(@priced_loader_row.id)
      assert MaterialPrice.exists?(@other_source_row.id)
    end

    test "confirm=yes is case-insensitive and tolerates whitespace" do
      assert_difference -> { MaterialPrice.count }, -3 do
        post admin_purge_junk_material_prices_path, params: { confirm: " YES " }
      end

      assert_response :success
      assert_equal "purged", JSON.parse(response.body)["status"]
    end

    test "confirm=no is treated as dry run" do
      assert_no_difference -> { MaterialPrice.count } do
        post admin_purge_junk_material_prices_path, params: { confirm: "no" }
      end

      assert_response :success
      assert_equal "dry_run", JSON.parse(response.body)["status"]
    end

    test "dry run returns zero rows when there is nothing to purge" do
      MaterialPrice.where(source: "bigbox_loader").where(price: nil).destroy_all

      post admin_purge_junk_material_prices_path

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "dry_run", body["status"]
      assert_equal 0, body["count"]
      assert_empty body["rows"]
    end
  end
end
