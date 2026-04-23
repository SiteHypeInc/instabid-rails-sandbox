require "test_helper"

class MaterialListGeneratorHvacTest < ActiveSupport::TestCase
  test "furnace default 2000 sqft med size" do
    result = MaterialListGenerator.call(
      trade:    "hvac",
      criteria: { squareFeet: 2000 }
    )

    assert_equal "hvac", result[:trade]
    refute result.key?(:complexity_multiplier)

    items = result[:material_list].index_by { |i| i[:item] }
    furnace = items.fetch("Standard Furnace")
    assert_in_delta 3500.0, furnace[:total_cost] # 3500 * 1.0 size
    assert_in_delta 350.0, items.fetch("Smart Thermostat")[:total_cost]
    refute items.key?("Refrigerant") # furnace has none
    refute items.key?("New Ductwork")

    assert_in_delta 4050.0, result[:total_material_cost] # 3500 + 350 + 200
    assert_in_delta 12.0, result[:labor_hours]
  end

  test "heatpump high-efficiency 3000 sqft new ducts 2 thermostats 2 stories" do
    result = MaterialListGenerator.call(
      trade:    "hvac",
      criteria: {
        squareFeet:  3000,
        systemType:  "heatpump",
        efficiency:  "high",
        ductwork:    "new",
        thermostats: 2,
        stories:     2
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    # size_large 1.2 on high-efficiency heatpump 7500
    assert_in_delta 9000.0, items.fetch("High-Efficiency Heat Pump")[:total_cost]
    assert_equal 300, items.fetch("New Ductwork")[:quantity] # ceil(3000/10)
    assert_in_delta 4500.0, items.fetch("New Ductwork")[:total_cost]
    assert_in_delta 700.0, items.fetch("Smart Thermostat")[:total_cost] # 2 * 350
    assert_in_delta 250.0, items.fetch("Refrigerant")[:total_cost]
    assert_in_delta 200.0, items.fetch("Filters & Supplies")[:total_cost]

    assert_in_delta 14_650.0, result[:total_material_cost]
    # labor: 14 + 300/20 = 29, * 1.2 = 34.8
    assert_in_delta 34.8, result[:labor_hours], 0.01
  end

  test "minisplit 4 zones 1600 sqft" do
    result = MaterialListGenerator.call(
      trade:    "hvac",
      criteria: { squareFeet: 1600, systemType: "minisplit", zoneCount: 4 }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    zone_line = items.fetch("Mini-Split System (4 zones)")
    # 2500 * 4 zones * 1.0 size_med = 10000
    assert_in_delta 10_000.0, zone_line[:total_cost]
    refute items.key?("New Ductwork")

    assert_in_delta 10_800.0, result[:total_material_cost]
    # labor: 8 * 4 zones = 32, no story mult
    assert_in_delta 32.0, result[:labor_hours]
  end

  test "small AC 1200 sqft repair ductwork 3 stories" do
    result = MaterialListGenerator.call(
      trade:    "hvac",
      criteria: { squareFeet: 1200, systemType: "ac", ductwork: "repair", stories: 3 }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    # size_small 0.9 × 4000 = 3600
    assert_in_delta 3600.0, items.fetch("Central AC Unit")[:total_cost]
    assert_equal 60, items.fetch("Ductwork Repair")[:quantity] # ceil(1200/20)
    assert_in_delta 480.0, items.fetch("Ductwork Repair")[:total_cost]

    assert_in_delta 4880.0, result[:total_material_cost]
    # labor: 10 + 60/30 = 12, * 1.4 (3 stories) = 16.8
    assert_in_delta 16.8, result[:labor_hours], 0.01
  end

  test "xlarge furnace 5000 sqft" do
    result = MaterialListGenerator.call(
      trade:    "hvac",
      criteria: { squareFeet: 5000 }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    # size_xlarge 1.4 × 3500 = 4900
    assert_in_delta 4900.0, items.fetch("Standard Furnace")[:total_cost]
    assert_in_delta 5450.0, result[:total_material_cost] # 4900 + 350 + 200
  end

  test "snake_case criteria keys" do
    result = MaterialListGenerator.call(
      trade:    "hvac",
      criteria: { square_feet: 2000, system_type: "minisplit", zone_count: 2 }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Mini-Split System (2 zones)")
    # 2500 * 2 zones * 1.0 = 5000
    assert_in_delta 5000.0, items.fetch("Mini-Split System (2 zones)")[:total_cost]
  end
end
