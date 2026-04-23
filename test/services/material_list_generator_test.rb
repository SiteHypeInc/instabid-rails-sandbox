require "test_helper"

class MaterialListGeneratorTest < ActiveSupport::TestCase
  test "roofing baseline: 2000 sqft architectural, 6/12, no extras" do
    result = MaterialListGenerator.call(
      trade:    "roofing",
      criteria: { squareFeet: 2000, material: "architectural" }
    )

    assert_equal "roofing", result[:trade]
    assert_equal 1.1,       result[:complexity_multiplier]
    assert_equal 88.0,      result[:labor_hours]

    items = result[:material_list].index_by { |i| i[:item] }

    shingles = items.fetch("Architectural Shingles")
    assert_equal 66,      shingles[:quantity]
    assert_equal "bundles", shingles[:unit]
    assert_in_delta 44.96, shingles[:unit_cost]
    assert_in_delta 2967.36, shingles[:total_cost]

    underlayment = items.fetch("Underlayment")
    assert_equal 5, underlayment[:quantity]
    assert_in_delta 225.0, underlayment[:total_cost]

    nails = items.fetch("Roofing Nails")
    assert_equal 2, nails[:quantity]
    assert_in_delta 170.0, nails[:total_cost]

    starter = items.fetch("Starter Shingles")
    assert_equal 179, starter[:quantity]
    assert_in_delta 447.50, starter[:total_cost]

    ridge = items.fetch("Ridge Cap")
    assert_equal 23, ridge[:quantity]
    assert_in_delta 69.0, ridge[:total_cost]

    drip = items.fetch("Drip Edge")
    assert_equal 179, drip[:quantity]
    assert_in_delta 492.25, drip[:total_cost]

    ice = items.fetch("Ice & Water Shield")
    assert_equal 72, ice[:quantity]
    assert_in_delta 324.0, ice[:total_cost]

    vents = items.fetch("Roof Vents")
    assert_equal 14, vents[:quantity]
    assert_in_delta 350.0, vents[:total_cost]

    disposal = items.fetch("Disposal/Dumpster")
    assert_equal 1, disposal[:quantity]
    assert_in_delta 800.0, disposal[:total_cost]

    assert_in_delta 5845.11, result[:total_material_cost], 0.01
  end

  test "roofing optional lines turn on with criteria" do
    result = MaterialListGenerator.call(
      trade:    "roofing",
      criteria: {
        squareFeet:       2000,
        material:         "architectural",
        chimneys:         2,
        skylights:        1,
        valleys:          3,
        plywoodSqft:      320,
        ridgeVentFeet:    40,
        existingRoofType: "metal",
        layers:           2,
        pitch:            "9/12"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }

    assert_equal 1.3,   result[:complexity_multiplier]
    assert_equal 112.0, result[:labor_hours] # 2000 * 0.04 * 1.3 + 2*3 + 1*2 = 104 + 6 + 2

    rv = items.fetch("Ridge Vent")
    assert_equal 40, rv[:quantity]
    assert_in_delta 220.0, rv[:total_cost]

    osb = items.fetch("OSB Sheathing")
    assert_equal 11, osb[:quantity] # ceil((320/32)*1.10) = ceil(11) = 11
    assert_in_delta 308.0, osb[:total_cost]

    chim = items.fetch("Chimney Flashing Kit")
    assert_equal 2, chim[:quantity]
    assert_in_delta 250.0, chim[:total_cost]

    sky = items.fetch("Skylight Flashing Kit")
    assert_equal 1, sky[:quantity]
    assert_in_delta 85.0, sky[:total_cost]

    valley = items.fetch("Valley Flashing")
    assert_equal 30, valley[:quantity]
    assert_in_delta 180.0, valley[:total_cost]

    disposal = items.fetch("Disposal/Dumpster")
    assert_equal 2, disposal[:quantity] # layers = 2
    assert_in_delta 2000.0, disposal[:total_cost] # 2000 * 2 * 0.50
  end

  test "roofing metal material uses sqft calc method" do
    result = MaterialListGenerator.call(
      trade:    "roofing",
      criteria: { squareFeet: 2000, material: "metal" }
    )

    metal = result[:material_list].find { |i| i[:item] == "Metal Roofing" }
    assert_equal 2200, metal[:quantity] # ceil(2000 * 1.10)
    assert_equal "sqft", metal[:unit]
    assert_in_delta 9.50, metal[:unit_cost]
    assert_in_delta 20_900.00, metal[:total_cost]
  end

  test "roofing defaults to architectural bundle when material is blank" do
    result = MaterialListGenerator.call(trade: "roofing", criteria: {})

    shingles = result[:material_list].first
    assert_equal "Architectural Shingles", shingles[:item]
    assert_equal "bundles",                 shingles[:unit]
    assert_in_delta 44.96,                  shingles[:unit_cost]
  end

  test "accepts snake_case criteria keys interchangeably" do
    result = MaterialListGenerator.call(
      trade:    "roofing",
      criteria: { square_feet: 2000, plywood_sqft: 320, ridge_vent_feet: 40, existing_roof_type: "tile", material: "tile" }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Tile Roofing")
    assert items.key?("OSB Sheathing")
    assert items.key?("Ridge Vent")

    disposal = items.fetch("Disposal/Dumpster")
    assert_in_delta 1500.0, disposal[:total_cost] # 2000 * 1 * 0.75
  end
end
