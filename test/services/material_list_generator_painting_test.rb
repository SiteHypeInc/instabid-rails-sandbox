require "test_helper"

class MaterialListGeneratorPaintingTest < ActiveSupport::TestCase
  test "exterior default 2000 sqft, 1 story, 2 coats, good siding" do
    result = MaterialListGenerator.call(
      trade:    "painting",
      criteria: { squareFeet: 2000 }
    )

    assert_equal "painting", result[:trade]
    # TEA-234 smoke #5: painting prices labor per-sqft; labor_hours surfaces
    # an equivalent-hours rollup (labor_cost / hourly_rate) so the totals
    # card + remodel grand-total reflect real effort. 7500 / 65 ≈ 115.4
    assert_in_delta 115.4, result[:labor_hours], 0.1
    refute result.key?(:complexity_multiplier)

    items = result[:material_list].index_by { |i| i[:item] }
    ext_mat   = items.fetch("Exterior Paint Materials (2 coats, 1 story)")
    ext_labor = items.fetch("Exterior Labor (2 coats, 1 story)")

    # 2000 * 0.45 * 1.5 * 1.0 = 1350
    assert_in_delta 1350.0, ext_mat[:total_cost]
    # 2000 * 2.50 * 1.5 * 1.0 * 1.0 = 7500
    assert_in_delta 7500.0, ext_labor[:total_cost]

    assert_in_delta 1350.0, result[:total_material_cost]
    assert_in_delta 7500.0, result[:labor_cost]
  end

  test "interior 1200 sqft, 3 coats, with ceilings, smooth walls" do
    result = MaterialListGenerator.call(
      trade:    "painting",
      criteria: { squareFeet: 1200, paintType: "interior", coats: 3, includeCeilings: "yes" }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    int_mat   = items.fetch("Interior Paint Materials (3 coats)")
    int_labor = items.fetch("Interior Labor (3 coats)")
    ceil_mat  = items.fetch("Ceiling Paint Materials")
    ceil_lab  = items.fetch("Ceiling Labor")

    # coat_mult = 2.0
    assert_in_delta 1080.0, int_mat[:total_cost]   # 1200 * 0.45 * 2
    assert_in_delta 8400.0, int_labor[:total_cost] # 1200 * 3.50 * 2 * 1.0
    assert_equal 1080, ceil_mat[:quantity]          # round(1200 * 0.9)
    assert_in_delta 756.0, ceil_mat[:total_cost]    # 1080 * 0.35 * 2
    assert_in_delta 2700.0, ceil_lab[:total_cost]   # 1080 * 1.25 * 2

    # materials = 1080 + 756 = 1836; labor = 8400 + 2700 = 11100
    assert_in_delta 1836.0, result[:total_material_cost]
    assert_in_delta 11_100.0, result[:labor_cost]
  end

  test "both paint type splits sqft 50/50 across int+ext with story and condition mults" do
    result = MaterialListGenerator.call(
      trade:    "painting",
      criteria: {
        squareFeet:       2000,
        paintType:        "both",
        stories:          2,
        coats:            2,
        sidingCondition:  "fair",      # 1.15
        wallCondition:    "textured"   # 1.10
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    # ext_sqft = int_sqft = 1000
    # coat_mult=1.5, story_mult=1.15
    # interior wall cond = 1.10
    int_mat = items.fetch("Interior Paint Materials (2 coats)")
    int_lab = items.fetch("Interior Labor (2 coats)")
    assert_in_delta 675.0, int_mat[:total_cost]                 # 1000*0.45*1.5
    assert_in_delta 5775.0, int_lab[:total_cost]                # 1000*3.50*1.5*1.10

    # exterior cond = 1.15
    ext_mat = items.fetch("Exterior Paint Materials (2 coats, 2 stories)")
    ext_lab = items.fetch("Exterior Labor (2 coats, 2 stories)")
    assert_in_delta 776.25, ext_mat[:total_cost]                # 1000*0.45*1.5*1.15
    assert_in_delta 4959.38, ext_lab[:total_cost], 0.01         # 1000*2.50*1.5*1.15*1.15

    assert_in_delta 1451.25, result[:total_material_cost]
    assert_in_delta 10_734.38, result[:labor_cost], 0.01
  end

  test "full exterior job with every add-on" do
    result = MaterialListGenerator.call(
      trade:    "painting",
      criteria: {
        squareFeet:          1000,
        paintType:           "exterior",
        powerWashing:        "yes",
        trimLinearFeet:      100,
        doorCount:           5,
        windowCount:         3,
        patchingNeeded:      "minor",
        colorChangeDramatic: "yes",
        leadPaint:           "yes"
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Power Washing Materials")
    assert items.key?("Wall Patching Materials (minor)")
    assert items.key?("Trim Materials")
    assert items.key?("Door Painting Materials")
    assert items.key?("Window Trim Materials")
    assert items.key?("Extra Primer Materials (Color Change)")
    assert items.key?("Lead Paint Abatement Materials")

    # materials: 675 (ext) + 100 (pw) + 50 (patch) + 50 (trim) + 75 (doors)
    #          + 30 (windows) + 200 (primer) + 150 (lead) = 1330
    assert_in_delta 1330.0, result[:total_material_cost]
    # labor: 3750 (ext) + 150 (pw) + 100 (patch) + 200 (trim) + 300 (doors)
    #      + 120 (windows) + 300 (primer) + 350 (lead) = 5270
    assert_in_delta 5270.0, result[:labor_cost]
  end

  test "patching moderate vs extensive tiers" do
    mod = MaterialListGenerator.call(trade: "painting", criteria: { squareFeet: 0, patchingNeeded: "moderate" })
    mod_items = mod[:material_list].index_by { |i| i[:item] }
    assert_in_delta 100.0, mod_items.fetch("Wall Patching Materials (moderate)")[:total_cost]
    assert_in_delta 250.0, mod_items.fetch("Wall Patching Labor (moderate)")[:total_cost]

    ext = MaterialListGenerator.call(trade: "painting", criteria: { squareFeet: 0, patchingNeeded: "extensive" })
    ext_items = ext[:material_list].index_by { |i| i[:item] }
    assert_in_delta 250.0, ext_items.fetch("Wall Patching Materials (extensive)")[:total_cost]
    assert_in_delta 500.0, ext_items.fetch("Wall Patching Labor (extensive)")[:total_cost]
  end

  test "snake_case criteria keys" do
    result = MaterialListGenerator.call(
      trade:    "painting",
      criteria: {
        square_feet:       1000,
        paint_type:        "interior",
        include_ceilings:  "yes",
        wall_condition:    "smooth",
        coats:             1,
        trim_linear_feet:  50,
        door_count:        2
      }
    )

    items = result[:material_list].index_by { |i| i[:item] }
    assert items.key?("Interior Paint Materials (1 coat)")
    assert items.key?("Interior Labor (1 coat)")
    assert items.key?("Ceiling Paint Materials")
    assert items.key?("Trim Materials")
    assert items.key?("Door Painting Materials")
  end
end
