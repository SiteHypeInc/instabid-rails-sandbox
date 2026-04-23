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

    test "GET remodel mode renders type tabs + preset selectors + section fields" do
      get admin_test_estimate_path, params: { mode: "remodel" }
      assert_response :success
      %w[kitchen bathroom addition].each do |type|
        assert_match(/data-remodel-type=\"#{type}\"/, @response.body)
      end
      assert_match(/Full Gut Same Layout/, @response.body)
      assert_match(/Standard Full Bath/, @response.body)
      assert_match(/Builder Grade Finish/, @response.body)
      # A known section field for each type
      assert_match(/remodel\[kitchen\]\[cabinets\]\[base_cabinet_lf\]/, @response.body)
      assert_match(/remodel\[bathroom\]\[bathing\]\[bathing_type\]/, @response.body)
      assert_match(/remodel\[addition\]\[shell\]\[foundation_type\]/, @response.body)
    end

    test "POST kitchen full_gut activates multiple trades and renders project total" do
      post admin_test_estimate_path, params: {
        mode:            "remodel",
        hourly_rate:     "65",
        remodel_type:    "kitchen",
        remodel_preset:  "full_gut",
        remodel: {
          "kitchen" => {
            "scope"      => { "kitchen_sqft" => "180", "layout_change" => "none" },
            "cabinets"   => { "base_cabinet_lf" => "18", "wall_cabinet_lf" => "14", "cabinet_grade" => "semi_custom" },
            "countertops"=> { "counter_sqft" => "40", "counter_material" => "quartz" },
            "backsplash" => { "backsplash_type" => "subway", "backsplash_sqft" => "27" },
            "appliances" => { "appliance_pkg" => "mid", "range_type" => "gas", "ventilation" => "wall_vented" },
            "flooring"   => { "flooring_material" => "lvp", "flooring_sqft" => "180", "floor_removal" => "yes" },
            "plumbing"   => { "sink_relocation" => "no", "dishwasher_hookup" => "yes", "garbage_disposal" => "yes", "ice_maker_line" => "yes" },
            "electrical" => { "recessed_lights" => "6", "pendant_lights" => "3", "gfci_outlets" => "4" },
            "painting"   => { "ceiling_paint" => "yes" },
            "hvac"       => { "hvac_changes" => "none" }
          }
        }
      }
      assert_response :success
      assert_match(/Results/, @response.body)
      # Ported trades render real numbers
      assert_match(/Flooring/, @response.body)
      assert_match(/Painting/, @response.body)
      assert_match(/Electrical Finish|Electrical Rough/, @response.body)
      # Unported trades render placeholder
      assert_match(/Builder not ported/, @response.body)
      # Summary renders
      assert_match(/Direct Total/, @response.body)
      assert_match(/GC Overhead/, @response.body)
      assert_match(/Contingency/, @response.body)
      assert_match(/Project Total/, @response.body)
    end

    test "POST bathroom standard runs plumbing + electrical and flags missing builders" do
      post admin_test_estimate_path, params: {
        mode:           "remodel",
        hourly_rate:    "65",
        remodel_type:   "bathroom",
        remodel_preset: "standard",
        remodel: {
          "bathroom" => {
            "scope"      => { "bathroom_sqft" => "80", "bathroom_type" => "primary", "layout_change" => "none" },
            "bathing"    => { "bathing_type" => "walk_in_shower", "shower_size" => "48x36" },
            "vanity"     => { "vanity_type" => "semi_custom", "vanity_width" => "48", "counter_material" => "quartz" },
            "tile"       => { "floor_tile_material" => "porcelain", "floor_tile_sqft" => "80" },
            "toilet_fix" => { "toilet_type" => "comfort", "faucet_grade" => "mid" },
            "systems"    => { "exhaust_fan" => "standard", "vanity_lighting" => "2", "recessed_lights" => "2", "gfci_outlets" => "1" },
            "painting"   => { "ceiling_paint" => "yes" }
          }
        }
      }
      assert_response :success
      assert_match(/Standard Full Bath/, @response.body)
      assert_match(/Project Total/, @response.body)
      assert_match(/Builder not ported/, @response.body)
    end

    test "POST addition builder grade runs shell + interior trades" do
      post admin_test_estimate_path, params: {
        mode:           "remodel",
        hourly_rate:    "65",
        remodel_type:   "addition",
        remodel_preset: "builder",
        remodel: {
          "addition" => {
            "scope"    => { "room_type" => "family_room", "addition_sqft" => "400", "stories" => "one" },
            "shell"    => { "foundation_type" => "slab", "roof_tie_in" => "gable", "exterior_finish" => "fiber_cement", "windows" => "3", "exterior_doors" => "1" },
            "interior" => { "flooring_material" => "lvp", "trim_level" => "standard", "paint_level" => "standard", "ceiling_height" => "9ft" },
            "systems"  => { "hvac_scope" => "extend", "recessed_lights" => "6", "ceiling_fan" => "yes", "insulation_type" => "batt" }
          }
        }
      }
      assert_response :success
      assert_match(/Roofing/, @response.body)
      assert_match(/Siding/, @response.body)
      assert_match(/Flooring/, @response.body)
      assert_match(/Electrical/, @response.body)
      assert_match(/HVAC/, @response.body)
      assert_match(/Project Total/, @response.body)
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

    # -------- TEA-234 rework (smoke-driven) --------

    test "smoke #1a: squareFeet=0 rejects with explicit error, no itemized $0 estimate" do
      post admin_test_estimate_path, params: {
        mode: "single",
        trade: "roofing",
        hourly_rate: "65",
        criteria: { "roofing" => { "squareFeet" => "0", "pitch" => "6/12" } }
      }
      assert_response :success
      assert_match(/Input errors/, @response.body)
      refute_match(/Trade Total/, @response.body)
    end

    test "smoke #1b: negative squareFeet rejected before generator Math.sqrt blows up" do
      post admin_test_estimate_path, params: {
        mode: "single",
        trade: "roofing",
        hourly_rate: "65",
        criteria: { "roofing" => { "squareFeet" => "-500", "pitch" => "6/12" } }
      }
      assert_response :success
      assert_match(/Input errors/, @response.body)
      refute_match(/Math::DomainError/, @response.body)
      refute_match(/Trade Total/, @response.body)
    end

    test "smoke #1c: non-numeric squareFeet rejected cleanly" do
      post admin_test_estimate_path, params: {
        mode: "single",
        trade: "roofing",
        hourly_rate: "65",
        criteria: { "roofing" => { "squareFeet" => "not a number", "pitch" => "6/12" } }
      }
      assert_response :success
      assert_match(/Input errors/, @response.body)
    end

    test "smoke #2: Source column renders [Manual] tag per line (not category)" do
      post admin_test_estimate_path, params: {
        mode: "single", trade: "roofing", hourly_rate: "65",
        criteria: { "roofing" => { "squareFeet" => "2000", "pitch" => "6/12", "material" => "architectural" } }
      }
      assert_response :success
      # Materials table has Source column populated with source label, not raw category
      assert_match(/\[Manual\]/, @response.body)
    end

    test "smoke #3: drywall remodel no longer returns silent empty material list" do
      result = MaterialListGenerator.call(
        trade: "drywall",
        criteria: { squareFeet: 2000, projectType: "remodel", rooms: 4,
                    ceilingHeight: "8ft", finishLevel: "level_4_smooth",
                    textureType: "orange_peel", damageExtent: "moderate" }
      )
      assert_operator result[:material_list].size, :>, 0, "drywall remodel must emit line items"
      assert_operator result[:total_material_cost], :>, 0, "drywall remodel must have non-zero materials"
      assert_operator result[:labor_hours], :>, 0, "drywall remodel must have non-zero labor"
    end

    test "smoke #4: plumbing remodel threads fixture counts through to line items" do
      result = MaterialListGenerator.call(
        trade: "plumbing",
        criteria: {
          serviceType: "remodel",
          bathrooms:   2, kitchens: 1,
          toiletCount: 2, sinkCount: 3, faucetCount: 3, tubShowerCount: 2
        }
      )
      items = result[:material_list].map { |l| l[:item] }
      assert_includes items, "Toilet Installation"
      assert_includes items, "Sink Installation"
      assert_includes items, "Faucet Installation"
      assert_includes items, "Tub/Shower Installation"
      # Rough-in piping should also be present for serviceType=remodel
      assert_includes items, "PEX Supply Lines (rough-in)"
      assert_includes items, "DWV Drain Lines"
    end

    test "smoke #4b: plumbing rough_in emits pipe scaled to fixture counts" do
      result = MaterialListGenerator.call(
        trade: "plumbing",
        criteria: { serviceType: "rough_in", bathrooms: 2, kitchens: 1, laundryRooms: 1 }
      )
      items = result[:material_list].map { |l| l[:item] }
      assert_includes items, "PEX Supply Lines (rough-in)"
      assert_includes items, "DWV Drain Lines"
      assert_includes items, "Shutoff Valves"
      assert_operator result[:labor_hours], :>, 0
    end

    test "smoke #4c: plumbing fixture_swap is an alias for fixture" do
      swap = MaterialListGenerator.call(
        trade: "plumbing",
        criteria: { serviceType: "fixture_swap", toiletCount: 1, sinkCount: 1 }
      )
      fixture = MaterialListGenerator.call(
        trade: "plumbing",
        criteria: { serviceType: "fixture", toiletCount: 1, sinkCount: 1 }
      )
      assert_equal fixture[:total_material_cost], swap[:total_material_cost]
      assert_equal fixture[:labor_hours],         swap[:labor_hours]
    end

    test "smoke #5: painting labor_hours is non-zero (equivalent-hours rollup)" do
      result = MaterialListGenerator.call(
        trade: "painting",
        criteria: { squareFeet: 2000, paintType: "interior", coats: 2 }
      )
      assert_operator result[:labor_cost],  :>, 0
      assert_operator result[:labor_hours], :>, 0, "painting should surface equivalent labor hours, not 0"
    end

    test "InvalidCriteria from generator surfaces as error, not 500" do
      post admin_test_estimate_path, params: {
        mode: "single", trade: "plumbing", hourly_rate: "65",
        criteria: { "plumbing" => { "squareFeet" => "-100" } }
      }
      assert_response :success
      assert_match(/Input errors/, @response.body)
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
