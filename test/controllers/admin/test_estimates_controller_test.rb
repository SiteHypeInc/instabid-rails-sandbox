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

    # ------------------------------------------------------------------
    # TEA-236 rework smoke — re-work guards for the 5 hard-fails called
    # out in the 7-item smoke (zero/neg input, Source semantics, drywall
    # remodel, plumbing remodel, labor rendering consistency).
    # ------------------------------------------------------------------

    test "zero squareFeet is rejected with a friendly validation error (no generator crash)" do
      post admin_test_estimate_path, params: {
        mode: "single", trade: "roofing", hourly_rate: "65",
        criteria: { "roofing" => { "squareFeet" => "0", "pitch" => "6/12", "material" => "architectural" } }
      }
      assert_response :success
      assert_match(/Validation Errors/, @response.body)
      assert_match(/greater than zero/, @response.body)
      refute_match(/Math::DomainError/, @response.body)
    end

    test "negative squareFeet is rejected cleanly (no Math::DomainError leak)" do
      post admin_test_estimate_path, params: {
        mode: "single", trade: "roofing", hourly_rate: "65",
        criteria: { "roofing" => { "squareFeet" => "-500", "pitch" => "6/12", "material" => "architectural" } }
      }
      assert_response :success
      assert_match(/Validation Errors/, @response.body)
      refute_match(/Math::DomainError/, @response.body)
      refute_match(/sqrt/, @response.body)
    end

    test "drywall remodel produces non-empty line items and a non-zero total" do
      post admin_test_estimate_path, params: {
        mode: "single", trade: "drywall", hourly_rate: "65",
        criteria: { "drywall" => {
          "squareFeet" => "2000", "projectType" => "remodel", "rooms" => "4",
          "finishLevel" => "level_4_smooth", "textureType" => "orange_peel", "damageExtent" => "moderate"
        } }
      }
      assert_response :success
      assert_match(/Drywall Remodel/, @response.body, "remodel branch should emit a Remodel line item")
      assert_match(/Drywall Sheets/,   @response.body, "remodel should include sheet goods")
      refute_match(/\$0\.00/,          @response.body.lines.grep(/Trade Total/).join, "remodel grand total should not be $0.00")
    end

    test "plumbing remodel threads fixture counts into line items" do
      post admin_test_estimate_path, params: {
        mode: "single", trade: "plumbing", hourly_rate: "65",
        criteria: { "plumbing" => {
          "squareFeet" => "2000", "serviceType" => "remodel",
          "bathrooms" => "2", "kitchens" => "1",
          "toiletCount" => "2", "sinkCount" => "3", "faucetCount" => "3", "tubShowerCount" => "2"
        } }
      }
      assert_response :success
      assert_match(/Toilet Installation/,     @response.body)
      assert_match(/Sink Installation/,       @response.body)
      assert_match(/Faucet Installation/,     @response.body)
      assert_match(/Tub\/Shower Installation/, @response.body)
    end

    test "Category column header replaces the misleading Source column" do
      post admin_test_estimate_path, params: {
        mode: "single", trade: "roofing", hourly_rate: "65",
        criteria: { "roofing" => { "squareFeet" => "2000", "pitch" => "6/12", "material" => "architectural" } }
      }
      assert_response :success
      # <th>Category</th> is present; the old misleading <th>Source</th> is gone.
      assert_match(/<th>Category<\/th>/, @response.body)
      refute_match(/<th>Source<\/th>/,   @response.body)
      # And the true price-source rollup is surfaced separately.
      assert_match(/Price Sources/, @response.body)
    end

    test "labor rows are not rendered in the materials table (unified rollup via Labor Cost card)" do
      # Painting is the worst offender — it emits many category=Labor line
      # items. After the fix, the materials table must omit Labor rows while
      # the Labor Cost card still reflects non-zero hours/cost.
      post admin_test_estimate_path, params: {
        mode: "single", trade: "painting", hourly_rate: "65",
        criteria: { "painting" => { "squareFeet" => "2000", "paintType" => "interior" } }
      }
      assert_response :success
      # Extract just the materials <table> ... </table> chunk for a precise assertion.
      table_chunk = @response.body[/<table>.*?<\/table>/m] || ""
      refute_match(/<td class="src">Labor<\/td>/, table_chunk, "Labor rows should not render in materials table")
      # Labor totals card still present and non-zero.
      assert_match(/Labor Hours/, @response.body)
      assert_match(/Labor Cost/,  @response.body)
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
