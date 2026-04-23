require "test_helper"

class MaterialListGeneratorSidingTest < ActiveSupport::TestCase
  test "vinyl 1600 sqft baseline 1 story no extras" do
    result = MaterialListGenerator.call(
      trade:    "siding",
      criteria: { squareFeet: 1600 }
    )

    assert_equal "siding", result[:trade]
    refute result.key?(:complexity_multiplier)

    items = result[:material_list].index_by { |i| i[:item] }
    siding = items.fetch("Vinyl Siding")
    assert_equal 1793, siding[:quantity] # ceil(1600 * 1.12) — IEEE-754 ε → 1793
    assert_equal 5.50, siding[:unit_cost]
    # TEA-244: line total reconciles with displayed qty × unit_cost
    assert_in_delta 9861.5, siding[:total_cost] # 1793 * 5.50

    assert_equal 2, items.fetch("House Wrap")[:quantity]
    assert_equal 14, items.fetch("J-Channel")[:quantity] # ceil(160/12)
    assert_equal 6, items.fetch("Corner Posts")[:quantity] # 1 story → 6
    # perim = sqrt(1600)*4 = 160; soffit_sqft = 240
    assert_equal 240, items.fetch("Soffit")[:quantity]
    assert_in_delta 1920.0, items.fetch("Soffit")[:total_cost]
    assert_equal 160, items.fetch("Fascia")[:quantity]
    assert_in_delta 960.0, items.fetch("Fascia")[:total_cost]
    assert_in_delta 175.0, items.fetch("Fasteners, Flashing & Caulk")[:total_cost]

    refute items.key?("Old Siding Removal & Disposal")

    assert_in_delta 13_644.5, result[:total_material_cost]
    # 1600 * 3.50 / 45 = 124.444 → 124.44
    assert_in_delta 124.44, result[:labor_hours], 0.01
  end

  test "fiber_cement 2000 sqft 2 stories with windows doors trim removal" do
    result = MaterialListGenerator.call(
      trade:    "siding",
      criteria: {
        squareFeet:     2000,
        sidingType:     "fiber_cement",
        stories:        2,
        windowCount:    10,
        doorCount:      3,
        trimLinearFeet: 200,
        removal:        true
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert_in_delta 21_280.0, items.fetch("Fiber Cement Siding")[:total_cost] # 2240 * 9.50
    assert_equal 17, items.fetch("J-Channel")[:quantity] # ceil(200/12)
    assert_equal 12, items.fetch("Corner Posts")[:quantity] # 2 stories × 6
    assert_in_delta 550.0, items.fetch("Window Trim & Wrapping")[:total_cost]
    assert_in_delta 225.0, items.fetch("Door Trim & Wrapping")[:total_cost]
    # removal at 1.75/sqft
    assert_in_delta 3500.0, items.fetch("Old Siding Removal & Disposal")[:total_cost]

    # labor: 2000 * 5.50 / 45 = 244.444, * 1.25 = 305.556, + 2000*0.02 = 345.556 → 345.56
    assert_in_delta 345.56, result[:labor_hours], 0.01
  end

  test "wood_cedar normalizes to wood" do
    result = MaterialListGenerator.call(
      trade:    "siding",
      criteria: { squareFeet: 1000, sidingType: "wood_cedar" }
    )
    items = result[:material_list].index_by { |i| i[:item] }
    wood = items.fetch("Wood Siding")
    assert_equal 14.00, wood[:unit_cost]
  end

  test "metal_aluminum normalizes to metal" do
    result = MaterialListGenerator.call(
      trade:    "siding",
      criteria: { squareFeet: 1000, sidingType: "metal_aluminum" }
    )
    items = result[:material_list].index_by { |i| i[:item] }
    metal = items.fetch("Metal Siding")
    assert_equal 8.00, metal[:unit_cost]
  end

  test "trim defaults to sqrt(sqft) * 4 when not provided" do
    result = MaterialListGenerator.call(
      trade:    "siding",
      criteria: { squareFeet: 2500 } # sqrt=50, trim=200, j-channel ceil(200/12)=17
    )
    items = result[:material_list].index_by { |i| i[:item] }
    assert_equal 17, items.fetch("J-Channel")[:quantity]
  end

  test "stucco 3 stories with needsRemoval=yes" do
    result = MaterialListGenerator.call(
      trade:    "siding",
      criteria: { squareFeet: 1000, sidingType: "stucco", stories: 3, needsRemoval: "yes" }
    )
    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Stucco Siding")
    assert items.key?("Old Siding Removal & Disposal")
    # 1000 * 7.50 / 45 = 166.666..., * 1.5 = 250.0, + 1000*0.02 = 270.0
    assert_in_delta 270.0, result[:labor_hours], 0.01
    assert_equal 18, items.fetch("Corner Posts")[:quantity] # 3 × 6
  end

  test "snake_case keys and unknown siding type falls back to vinyl" do
    result = MaterialListGenerator.call(
      trade:    "siding",
      criteria: { square_feet: 1600, siding_type: "bogus", window_count: 2 }
    )
    items = result[:material_list].index_by { |i| i[:item] }
    bogus = items.fetch("Bogus Siding")
    assert_equal 5.50, bogus[:unit_cost] # vinyl fallback
    assert_in_delta 110.0, items.fetch("Window Trim & Wrapping")[:total_cost] # 2 * 55
  end
end
