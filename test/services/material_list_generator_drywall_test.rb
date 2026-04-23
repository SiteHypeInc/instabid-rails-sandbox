require "test_helper"

class MaterialListGeneratorDrywallTest < ActiveSupport::TestCase
  test "new construction baseline 2000 sqft, 5 rooms, 8ft, level 3, no texture" do
    result = MaterialListGenerator.call(
      trade:    "drywall",
      criteria: { squareFeet: 2000, rooms: 5 }
    )

    assert_equal "drywall", result[:trade]
    items = result[:material_list].index_by { |i| i[:item] }

    sheets = items.fetch('Drywall Sheets (4x8, 1/2")')
    assert_equal 70, sheets[:quantity] # ceil(2000 * 1.12 / 32) = ceil(70) = 70
    assert_in_delta 840.0, sheets[:total_cost]

    compound = items.fetch("Joint Compound")
    assert_equal 18, compound[:quantity] # ceil(70/4)
    assert_in_delta 324.0, compound[:total_cost]

    tape = items.fetch("Drywall Tape")
    assert_equal 9, tape[:quantity] # ceil(70/8)
    assert_in_delta 72.0, tape[:total_cost]

    screws = items.fetch("Drywall Screws")
    assert_equal 14, screws[:quantity] # ceil(70/5)
    assert_in_delta 168.0, screws[:total_cost]

    corners = items.fetch("Corner Beads (8ft)")
    assert_equal 20, corners[:quantity] # 5 rooms × 4
    assert_in_delta 100.0, corners[:total_cost]

    # labor: 2000 * 1.75 = 3500, / 65 = 53.8461..
    labor = items.fetch("Installation Labor (Level 3 Standard)")
    assert_equal 53.8, labor[:quantity]
    assert_equal 65, labor[:unit_cost]
    assert_in_delta 3500.0, labor[:total_cost], 0.01

    assert_in_delta 1504.0, result[:total_material_cost]
    assert_equal 53.8, result[:labor_hours]
  end

  test "new construction level 5 + 12ft ceiling + orange peel texture" do
    result = MaterialListGenerator.call(
      trade: "drywall",
      criteria: {
        squareFeet:    2000,
        rooms:         5,
        ceilingHeight: "12ft",
        finishLevel:   "level_5_glass",
        textureType:   "orange_peel"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    tex = items.fetch("Orange Peel Texture")
    assert_equal 2000.0, tex[:quantity]
    assert_in_delta 0.80, tex[:unit_cost]
    assert_in_delta 1600.0, tex[:total_cost]

    # labor: 3500 * 1.5 * 1.3 / 65 + 1600/65 = 6825/65 + 24.615 = 105 + 24.615 = 129.615
    assert_equal 129.6, result[:labor_hours]

    labor = items.fetch("Installation Labor (Level 5 Glass, 12ft+ ceilings)")
    assert_equal 129.6, labor[:quantity]

    assert_in_delta 3104.0, result[:total_material_cost] # 1504 + 1600
  end

  test "new construction level 4 + 10ft ceiling + knockdown texture" do
    result = MaterialListGenerator.call(
      trade: "drywall",
      criteria: {
        squareFeet:    1500,
        rooms:         4,
        ceilingHeight: "10ft",
        finishLevel:   "level_4_smooth",
        textureType:   "knockdown"
      }
    )
    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Knockdown Texture")
    labor = items.find { |k, _| k.start_with?("Installation Labor (Level 4 Smooth") }
    assert labor, "expected Level 4 Smooth labor line, got: #{items.keys.inspect}"
  end

  test "repair minor default, no texture, zero sqft" do
    result = MaterialListGenerator.call(
      trade:    "drywall",
      criteria: { projectType: "repair" }
    )
    items = result[:material_list].index_by { |i| i[:item] }
    assert_equal 1, items.fetch("Drywall Repair - Minor")[:quantity]
    assert_in_delta 175.0, items.fetch("Drywall Repair - Minor")[:total_cost]

    # labor: 175 * 0.7 / 65 = 1.884... → 1.9
    assert_equal 1.9, result[:labor_hours]
    assert_in_delta 175.0, result[:total_material_cost]
  end

  test "repair moderate with knockdown texture caps at 100 sqft" do
    result = MaterialListGenerator.call(
      trade: "drywall",
      criteria: {
        projectType:  "repair",
        damageExtent: "moderate",
        textureType:  "knockdown",
        squareFeet:   150
      }
    )
    items = result[:material_list].index_by { |i| i[:item] }
    assert_in_delta 400.0, items.fetch("Drywall Repair - Moderate")[:total_cost]

    tex = items.fetch("Knockdown Texture Match")
    assert_equal 100, tex[:quantity] # min(150, 100)
    assert_in_delta 100.0, tex[:total_cost]

    # labor: 400 * 0.7 / 65 + 100/65 = 4.307 + 1.538 = 5.846 → 5.8
    assert_equal 5.8, result[:labor_hours]
    assert_in_delta 500.0, result[:total_material_cost]
  end

  test "repair extensive no texture" do
    result = MaterialListGenerator.call(
      trade: "drywall",
      criteria: { projectType: "repair", damageExtent: "extensive" }
    )
    items = result[:material_list].index_by { |i| i[:item] }
    assert_in_delta 900.0, items.fetch("Drywall Repair - Extensive")[:total_cost]
    # 900 * 0.7 / 65 = 9.692 → 9.7
    assert_equal 9.7, result[:labor_hours]
  end

  test "return shape omits complexity_multiplier" do
    result = MaterialListGenerator.call(trade: "drywall", criteria: { squareFeet: 1000 })
    refute result.key?(:complexity_multiplier)
  end

  test "accepts snake_case criteria keys" do
    result = MaterialListGenerator.call(
      trade:    "drywall",
      criteria: { square_feet: 1500, rooms: 4, ceiling_height: 10, finish_level: "level_4_smooth", texture_type: "popcorn" }
    )
    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Popcorn Texture")
    labor_key = items.keys.find { |k| k.start_with?("Installation Labor (Level 4 Smooth, 10ft ceilings") }
    assert labor_key, "expected 10ft + level 4 labor line"
  end
end
