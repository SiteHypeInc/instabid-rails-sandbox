require "test_helper"

module Admin
  class BigboxDataLoadsControllerTest < ActionDispatch::IntegrationTest
    # TEA-157: the on-demand BigBox API path is gated by ALLOW_BIGBOX_ONDEMAND.
    # These tests pin the lockout so re-enabling the path requires an explicit
    # env flip, not a silent code change.

    teardown do
      ENV.delete("ALLOW_BIGBOX_ONDEMAND")
    end

    test "returns 503 with lockout hint when ALLOW_BIGBOX_ONDEMAND is unset" do
      ENV.delete("ALLOW_BIGBOX_ONDEMAND")

      post admin_pricing_load_path

      assert_response :service_unavailable

      body = JSON.parse(response.body)
      assert_match(/disabled/i, body["error"])
      assert_match(/ALLOW_BIGBOX_ONDEMAND/, body["hint"])
    end

    test "returns 503 when ALLOW_BIGBOX_ONDEMAND is set to something other than 'true'" do
      ENV["ALLOW_BIGBOX_ONDEMAND"] = "false"

      post admin_pricing_load_path

      assert_response :service_unavailable

      ENV["ALLOW_BIGBOX_ONDEMAND"] = "1"
      post admin_pricing_load_path
      assert_response :service_unavailable

      ENV["ALLOW_BIGBOX_ONDEMAND"] = ""
      post admin_pricing_load_path
      assert_response :service_unavailable
    end

    test "service raises OnDemandDisabledError when disabled" do
      ENV.delete("ALLOW_BIGBOX_ONDEMAND")

      assert_raises(BigboxDataLoaderService::OnDemandDisabledError) do
        BigboxDataLoaderService.load
      end
    end

    test "service raises OnDemandDisabledError on .new when disabled" do
      ENV.delete("ALLOW_BIGBOX_ONDEMAND")

      assert_raises(BigboxDataLoaderService::OnDemandDisabledError) do
        BigboxDataLoaderService.new
      end
    end

    test "does not leak a new material_prices row when lockout is active" do
      ENV.delete("ALLOW_BIGBOX_ONDEMAND")

      assert_no_difference -> { MaterialPrice.count } do
        post admin_pricing_load_path, params: { trade: "roofing" }
      end

      assert_response :service_unavailable
    end
  end
end
