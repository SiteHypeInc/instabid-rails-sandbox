require "test_helper"

module Admin
  class BigboxDataLoadsControllerTest < ActionDispatch::IntegrationTest
    # TEA-157: the on-demand BigBox API path is gated by ALLOW_BIGBOX_ONDEMAND.
    # These tests pin the lockout so re-enabling the path requires an explicit
    # env flip, not a silent code change.

    teardown do
      ENV.delete("ALLOW_BIGBOX_ONDEMAND")
    end

    # TEA-345: zip_code is now required upstream. Pin both the lockout and the
    # required-param behavior — neither path should ever leak a row.

    test "returns 503 with lockout hint when ALLOW_BIGBOX_ONDEMAND is unset" do
      ENV.delete("ALLOW_BIGBOX_ONDEMAND")

      post admin_pricing_load_path, params: { zip_code: "98101" }

      assert_response :service_unavailable

      body = JSON.parse(response.body)
      assert_match(/disabled/i, body["error"])
      assert_match(/ALLOW_BIGBOX_ONDEMAND/, body["hint"])
    end

    test "returns 503 when ALLOW_BIGBOX_ONDEMAND is set to something other than 'true'" do
      ENV["ALLOW_BIGBOX_ONDEMAND"] = "false"

      post admin_pricing_load_path, params: { zip_code: "98101" }

      assert_response :service_unavailable

      ENV["ALLOW_BIGBOX_ONDEMAND"] = "1"
      post admin_pricing_load_path, params: { zip_code: "98101" }
      assert_response :service_unavailable

      ENV["ALLOW_BIGBOX_ONDEMAND"] = ""
      post admin_pricing_load_path, params: { zip_code: "98101" }
      assert_response :service_unavailable
    end

    test "returns 400 when zip_code is missing (TEA-345)" do
      ENV.delete("ALLOW_BIGBOX_ONDEMAND")

      post admin_pricing_load_path

      assert_response :bad_request
      body = JSON.parse(response.body)
      assert_match(/zip_code/i, body["error"])
    end

    test "service raises OnDemandDisabledError when disabled" do
      ENV.delete("ALLOW_BIGBOX_ONDEMAND")

      assert_raises(BigboxDataLoaderService::OnDemandDisabledError) do
        BigboxDataLoaderService.load(zip_code: "98101")
      end
    end

    test "service raises OnDemandDisabledError on .new when disabled" do
      ENV.delete("ALLOW_BIGBOX_ONDEMAND")

      assert_raises(BigboxDataLoaderService::OnDemandDisabledError) do
        BigboxDataLoaderService.new(zip_code: "98101")
      end
    end

    test "does not leak a new material_prices row when lockout is active" do
      ENV.delete("ALLOW_BIGBOX_ONDEMAND")

      assert_no_difference -> { MaterialPrice.count } do
        post admin_pricing_load_path, params: { trade: "roofing", zip_code: "98101" }
      end

      assert_response :service_unavailable
    end
  end
end
