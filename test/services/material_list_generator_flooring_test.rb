require "test_helper"

class MaterialListGeneratorFlooringTest < ActiveSupport::TestCase
  test "carpet baseline 1000 sqft, no extras" do
    result = MaterialListGenerator.call(
      trade:    "flooring",
      criteria: { squareFeet: 1000 }
    )

    assert_equal "flooring", result[:trade]
    refute result.key?(:complexity_multiplier)

    items = result[:material_list].index_by { |i| i[:item] }
    carpet = items.fetch("Carpet Flooring")
    assert_equal 1100, carpet[:quantity] # ceil(1000 * 1.10)
    assert_equal 5.0, carpet[:unit_cost]
    assert_in_delta 5500.0, carpet[:total_cost]

    # no underlayment line when carpet
    refute items.key?("Underlayment")

    assert_in_delta 5500.0, result[:total_material_cost]
    # (1000 * 2.0) / 45 = 44.444... → 44.44
    assert_in_delta 44.44, result[:labor_hours], 0.01
  end

  test "lvp with underlayment + baseboard" do
    result = MaterialListGenerator.call(
      trade:    "flooring",
      criteria: { squareFeet: 800, flooringType: "lvp", baseboard: 100 }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    lvp = items.fetch("Lvp Flooring")
    assert_equal 881, lvp[:quantity] # ceil(800*1.10) — float ε carries to 881
    assert_in_delta 3960.0, lvp[:total_cost] # 880 * 4.50

    u = items.fetch("Underlayment")
    assert_equal 800, u[:quantity]
    assert_in_delta 400.0, u[:total_cost] # 800 * 0.50

    bb = items.fetch("Baseboard Trim")
    assert_equal 100, bb[:quantity]
    assert_in_delta 500.0, bb[:total_cost]

    assert_in_delta 4860.0, result[:total_material_cost]
    # labor: (800 * 2.50)/45 = 44.444... + 100/20 = 5 → 49.44
    assert_in_delta 49.44, result[:labor_hours], 0.01
  end

  test "porcelain tile with removal, subfloor repair, complex, baseboard" do
    result = MaterialListGenerator.call(
      trade:    "flooring",
      criteria: {
        squareFeet:     500,
        flooringType:   "tile_porcelain",
        removal:        true,
        subfloorRepair: true,
        complexity:     "complex",
        baseboard:      80
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    tile = items.fetch("Tile Porcelain Flooring")
    assert_equal 550, tile[:quantity] # ceil(500 * 1.10)
    assert_in_delta 5500.0, tile[:total_cost]

    u = items.fetch("Underlayment")
    assert_in_delta 250.0, u[:total_cost]

    rem = items.fetch("Old Flooring Removal")
    assert_equal 500, rem[:quantity]
    assert_in_delta 1000.0, rem[:total_cost]

    sub = items.fetch("Subfloor Repair")
    assert_equal 150, sub[:quantity] # ceil(500 * 0.3)
    assert_in_delta 600.0, sub[:total_cost]

    bb = items.fetch("Baseboard Trim")
    assert_equal 80, bb[:quantity]
    assert_in_delta 400.0, bb[:total_cost]

    assert_in_delta 7750.0, result[:total_material_cost]
    # (500*6.50)/45 = 72.222 * 1.4 = 101.111 + 500*0.02 + 500*0.01 + 80/20
    # = 101.111 + 10 + 5 + 4 = 120.111 → 120.11
    assert_in_delta 120.11, result[:labor_hours], 0.01
  end

  test "hardwood solid moderate with underlayment disabled" do
    result = MaterialListGenerator.call(
      trade:    "flooring",
      criteria: {
        squareFeet:    1200,
        flooringType:  "hardwood_solid",
        underlayment:  false,
        complexity:    "moderate"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Hardwood Solid Flooring")
    refute items.key?("Underlayment")

    # (1200 * 5.0)/45 = 133.333, * 1.2 = 160.0
    assert_in_delta 160.0, result[:labor_hours], 0.01
    # 1320 * 14.0
    assert_in_delta 18_480.0, result[:total_material_cost]
  end

  test "unknown flooring type falls back to vinyl pricing" do
    result = MaterialListGenerator.call(
      trade:    "flooring",
      criteria: { squareFeet: 400, flooringType: "bamboo" }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    row = items.fetch("Bamboo Flooring")
    assert_equal 3.5, row[:unit_cost]
    # labor fallback vinyl rate 2.50 → (400*2.50)/45 = 22.222 → 22.22
    assert_in_delta 22.22, result[:labor_hours], 0.01
  end

  test "snake_case criteria keys and string truthy removal" do
    result = MaterialListGenerator.call(
      trade:    "flooring",
      criteria: {
        square_feet:     600,
        flooring_type:   "laminate",
        subfloor_repair: true,
        removal:         "yes"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Laminate Flooring")
    assert items.key?("Old Flooring Removal")
    assert items.key?("Subfloor Repair")
    # laminate uses floor_labor_vinyl = 2.50
    # (600*2.50)/45 = 33.333 + 600*0.02 + 600*0.01 = 33.333 + 12 + 6 = 51.333 → 51.33
    assert_in_delta 51.33, result[:labor_hours], 0.01
  end
end
