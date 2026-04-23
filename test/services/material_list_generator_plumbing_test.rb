require "test_helper"

class MaterialListGeneratorPlumbingTest < ActiveSupport::TestCase
  test "general service call with empty criteria" do
    result = MaterialListGenerator.call(trade: "plumbing", criteria: {})

    assert_equal "plumbing", result[:trade]
    assert_in_delta 95.0, result[:total_material_cost]
    assert_equal 2.0, result[:labor_hours]

    items = result[:material_list].index_by { |i| i[:item] }
    assert_equal 1, items.fetch("Service Call")[:quantity]
    labor = items.fetch("Plumbing Labor (basement access)")
    assert_equal 65, labor[:unit_cost]
    assert_in_delta 130.0, labor[:total_cost]
    assert_equal "Labor", labor[:category]
  end

  test "general with all add-on flags yes" do
    result = MaterialListGenerator.call(
      trade: "plumbing",
      criteria: {
        garbageDisposal:     "yes",
        iceMaker:            "yes",
        waterSoftener:       "yes",
        mainLineReplacement: "yes",
        gasLineNeeded:       "yes"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Garbage Disposal Installation")
    assert items.key?("Ice Maker Line Installation")
    assert items.key?("Water Softener Installation")
    assert items.key?("Main Line Replacement")
    assert items.key?("Gas Line Installation")

    # labor: 2 + 1.5 + 1 + 4 + 8 + 4 = 20.5
    assert_equal 20.5, result[:labor_hours]
    # material: 95 + 325 + 150 + 1800 + 1200 + 500 = 4070
    assert_in_delta 4070.0, result[:total_material_cost]
  end

  test "repipe 2000 sqft baseline (2 baths, 1 kitchen, basement)" do
    result = MaterialListGenerator.call(
      trade: "plumbing",
      criteria: {
        serviceType: "repipe",
        squareFeet:  2000,
        bathrooms:   2,
        kitchens:    1,
        laundryRooms: 0,
        stories:     1,
        accessType:  "basement"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    pex = items.fetch("PEX Pipe")
    assert_equal 1080, pex[:quantity] # 2000*0.5 + 2*25 + 30 = 1080
    assert_in_delta 2700.0, pex[:total_cost]

    fittings = items.fetch("Fittings & Connectors")
    assert_in_delta 810.0, fittings[:total_cost] # 2700 * 0.30

    valves = items.fetch("Shutoff Valves")
    assert_equal 6, valves[:quantity] # 2*2 + 1*2 + 0
    assert_in_delta 150.0, valves[:total_cost]

    assert_equal 100.0, result[:labor_hours]
    assert_in_delta 3660.0, result[:total_material_cost]
  end

  test "repipe multi-story crawlspace with main line replacement" do
    result = MaterialListGenerator.call(
      trade: "plumbing",
      criteria: {
        serviceType:         "repipe",
        squareFeet:          2000,
        bathrooms:           2,
        kitchens:            1,
        stories:             3,
        accessType:          "crawlspace",
        mainLineReplacement: "yes"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Main Line Replacement")

    # 100 * 1.2 * 1.15 (stories >= 3) * 1.15 (crawlspace) + 8 (main line) = 166.7
    assert_equal 166.7, result[:labor_hours]
  end

  test "water heater tankless gas in attic" do
    result = MaterialListGenerator.call(
      trade: "plumbing",
      criteria: {
        serviceType:         "water_heater",
        heaterType:          "tankless",
        gasLineNeeded:       "yes",
        waterHeaterLocation: "attic"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    heater = items.fetch("Tankless Water Heater (Gas)")
    assert_in_delta 3500.0, heater[:unit_cost]

    supplies = items.fetch("Installation Supplies (flex lines, fittings)")
    assert_in_delta 150.0, supplies[:total_cost]

    gas = items.fetch("Gas Line Installation")
    assert_in_delta 500.0, gas[:total_cost]

    # 10 * 1.25 + 4 = 16.5
    assert_equal 16.5, result[:labor_hours]
    assert_in_delta 4150.0, result[:total_material_cost]
  end

  test "water heater tank default in garage" do
    result = MaterialListGenerator.call(
      trade: "plumbing",
      criteria: { serviceType: "water_heater" }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Tank Water Heater (50 gal)")
    assert_equal 6.0, result[:labor_hours] # 6 × 1.0
    assert_in_delta 1750.0, result[:total_material_cost] # 1600 + 150
  end

  test "fixture mixed install with dishwasher and crawlspace" do
    result = MaterialListGenerator.call(
      trade: "plumbing",
      criteria: {
        serviceType:      "fixture",
        toiletCount:      2,
        sinkCount:        1,
        tubShowerCount:   1,
        dishwasherHookup: "yes",
        accessType:       "crawlspace"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert_equal 2, items.fetch("Toilet Installation")[:quantity]
    assert_equal 1, items.fetch("Sink Installation")[:quantity]
    assert_equal 1, items.fetch("Tub/Shower Installation")[:quantity]
    assert items.key?("Dishwasher Hookup")

    # 2.5*2 + 3*1 + 6*1 + 2 = 16, * 1.15 = 18.4
    assert_equal 18.4, result[:labor_hours]
    # 750 + 450 + 1200 + 200 = 2600
    assert_in_delta 2600.0, result[:total_material_cost]
  end

  test "fixture labor has 2 hour minimum" do
    result = MaterialListGenerator.call(
      trade:    "plumbing",
      criteria: { serviceType: "fixture" }
    )
    assert_equal 2.0, result[:labor_hours]
  end

  test "plumbing return shape omits complexity_multiplier" do
    result = MaterialListGenerator.call(trade: "plumbing", criteria: {})
    refute result.key?(:complexity_multiplier)
  end

  test "accepts snake_case criteria keys" do
    result = MaterialListGenerator.call(
      trade:    "plumbing",
      criteria: { service_type: "water_heater", heater_type: "tankless", gas_line_needed: "yes" }
    )
    items = result[:material_list].map { |i| i[:item] }
    assert_includes items, "Tankless Water Heater (Gas)"
    assert_includes items, "Gas Line Installation"
  end
end
