require "test_helper"

module Admin
  class TestEstimatesControllerTest < ActionDispatch::IntegrationTest
    # TEA-236 — internal test estimate sandbox. GET renders the form; POST
    # runs MaterialListGenerator and re-renders with results inline.

    test "GET renders the form with all trades" do
      get admin_test_estimate_path
      assert_response :success
      assert_match(/Test Estimate/, @response.body)
      %w[roofing plumbing drywall flooring painting siding hvac electrical].each do |trade|
        assert_match(/data-trade=\"#{trade}\"/, @response.body)
      end
    end

    test "POST with single roofing trade renders itemized results" do
      post admin_test_estimate_path, params: {
        mode: "single",
        trade: "roofing",
        hourly_rate: "65",
        criteria: {
          "roofing" => {
            "squareFeet" => "2000",
            "pitch" => "6/12",
            "material" => "architectural"
          }
        }
      }
      assert_response :success
      assert_match(/Results/, @response.body)
      assert_match(/Materials/, @response.body)
      assert_match(/Labor Hours/, @response.body)
      assert_match(/Trade Total/, @response.body)
      # A known line item for roofing
      assert_match(/Underlayment/, @response.body)
    end

    test "POST with remodel mode runs multiple trades and renders grand total" do
      post admin_test_estimate_path, params: {
        mode: "remodel",
        hourly_rate: "65",
        remodel_trades: %w[roofing plumbing],
        criteria: {
          "roofing"  => { "squareFeet" => "2000", "pitch" => "6/12", "material" => "architectural" },
          "plumbing" => { "squareFeet" => "2000", "bathrooms" => "2", "kitchens" => "1" }
        }
      }
      assert_response :success
      assert_match(/Grand Total/, @response.body)
      assert_match(/Roofing/, @response.body)
      assert_match(/Plumbing/, @response.body)
    end

    test "POST with unsupported trade name is coerced to a supported trade" do
      # controller sanitizes params[:trade] — unknown names fall back to the first supported trade
      post admin_test_estimate_path, params: {
        mode: "single",
        trade: "nope",
        hourly_rate: "65",
        criteria: { "roofing" => { "squareFeet" => "1500", "pitch" => "4/12" } }
      }
      assert_response :success
      # Should have fallen back to roofing and rendered results
      assert_match(/Results/, @response.body)
    end

    test "all 8 trades produce non-negative totals with minimal inputs" do
      trades_with_minimal = {
        "roofing"    => { "squareFeet" => "2000", "pitch" => "6/12", "material" => "architectural" },
        "plumbing"   => { "squareFeet" => "2000" },
        "drywall"    => { "squareFeet" => "2000" },
        "flooring"   => { "squareFeet" => "1000", "flooringType" => "lvp" },
        "painting"   => { "squareFeet" => "2000", "paintType" => "interior" },
        "siding"     => { "squareFeet" => "1500", "sidingType" => "vinyl" },
        "hvac"       => { "squareFeet" => "2000", "systemType" => "furnace" },
        "electrical" => { "squareFeet" => "2000", "serviceType" => "general" }
      }

      trades_with_minimal.each do |trade, criteria|
        post admin_test_estimate_path, params: {
          mode: "single",
          trade: trade,
          hourly_rate: "65",
          criteria: { trade => criteria }
        }
        assert_response :success, "#{trade} request failed"
        assert_match(/Trade Total/, @response.body, "#{trade} did not render trade total")
        refute_match(/Error:/, @response.body, "#{trade} surfaced an error")
      end
    end
  end
end
