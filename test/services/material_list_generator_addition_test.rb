require "test_helper"

class MaterialListGeneratorAdditionTest < ActiveSupport::TestCase
  # TEA-240 Addition cluster: Framing, Foundation, Windows/Doors, Insulation,
  # Permits, Site Prep. Covers the Addition / Whole-Home Gut presets.

  def generate(trade, criteria)
    MaterialListGenerator.call(trade: trade, criteria: criteria, hourly_rate: 65)
  end

  # --- Framing --------------------------------------------------------------

  test "framing: wall LF + headers priced" do
    result = generate("framing", { framingWallLf: 100, headersCount: 3 })
    wall = result[:material_list].find { |l| l[:item].include?("Wall Framing") }
    assert_equal 100.0, wall[:quantity]
    headers = result[:material_list].find { |l| l[:item] == "Framing Headers" }
    assert_equal 3, headers[:quantity]
    assert_equal 145.00, headers[:unit_cost]
    assert result[:labor_hours] > 0
    assert_every_line_priced(result)
  end

  test "framing: tall walls cost more than 9ft" do
    std = generate("framing", { framingWallLf: 100, wallHeight: 9 })
    tall = generate("framing", { framingWallLf: 100, wallHeight: 12 })
    assert tall[:total_material_cost] > std[:total_material_cost]
  end

  test "framing: zero LF returns empty" do
    result = generate("framing", { framingWallLf: 0 })
    assert_empty result[:material_list]
  end

  # --- Foundation -----------------------------------------------------------

  test "foundation: slab baseline" do
    result = generate("foundation", { foundationType: "slab", foundationSqft: 800 })
    line = result[:material_list].find { |l| l[:item].include?("Slab") }
    assert_equal 800.0, line[:quantity]
    assert_equal 14.00, line[:unit_cost]
    assert_every_line_priced(result)
  end

  test "foundation: crawlspace is priciest" do
    slab = generate("foundation", { foundationType: "slab", foundationSqft: 800 })
    crawl = generate("foundation", { foundationType: "crawlspace", foundationSqft: 800 })
    pier = generate("foundation", { foundationType: "pier", foundationSqft: 800 })
    assert pier[:total_material_cost] < slab[:total_material_cost]
    assert slab[:total_material_cost] < crawl[:total_material_cost]
  end

  test "foundation: zero sqft returns empty" do
    result = generate("foundation", { foundationType: "slab", foundationSqft: 0 })
    assert_empty result[:material_list]
  end

  # --- Windows / Doors ------------------------------------------------------

  test "windows_doors: premium windows with doors" do
    result = generate("windows_doors", {
      windowCount:        6,
      windowGrade:        "premium",
      exteriorDoorCount:  1,
      interiorDoorCount:  4,
    })
    win = result[:material_list].find { |l| l[:item].include?("Windows") }
    assert_equal 6, win[:quantity]
    assert_equal 950.00, win[:unit_cost]
    assert result[:material_list].any? { |l| l[:item] == "Exterior Doors" }
    assert result[:material_list].any? { |l| l[:item] == "Interior Doors" }
    assert_every_line_priced(result)
  end

  test "windows_doors: builder grade is cheapest" do
    b = generate("windows_doors", { windowCount: 6, windowGrade: "builder" })
    m = generate("windows_doors", { windowCount: 6, windowGrade: "mid" })
    p = generate("windows_doors", { windowCount: 6, windowGrade: "premium" })
    assert b[:total_material_cost] < m[:total_material_cost]
    assert m[:total_material_cost] < p[:total_material_cost]
  end

  test "windows_doors: all-zero returns empty" do
    result = generate("windows_doors", { windowCount: 0 })
    assert_empty result[:material_list]
  end

  # --- Insulation -----------------------------------------------------------

  test "insulation: batt baseline" do
    result = generate("insulation", { insulationType: "batt", insulationSqft: 1200 })
    line = result[:material_list].find { |l| l[:item].include?("Batt") }
    assert_equal 1200.0, line[:quantity]
    assert_equal 1.35, line[:unit_cost]
    assert_every_line_priced(result)
  end

  test "insulation: spray foam is priciest" do
    batt = generate("insulation", { insulationType: "batt", insulationSqft: 1000 })
    spray = generate("insulation", { insulationType: "spray", insulationSqft: 1000 })
    assert spray[:total_material_cost] > batt[:total_material_cost]
  end

  test "insulation: zero sqft returns empty" do
    result = generate("insulation", { insulationSqft: 0 })
    assert_empty result[:material_list]
  end

  # --- Permits --------------------------------------------------------------

  test "permits: full permit scales with project cost" do
    small = generate("permits", { permitType: "full", projectCost: 50_000 })
    large = generate("permits", { permitType: "full", projectCost: 250_000 })
    assert large[:total_material_cost] > small[:total_material_cost]
    assert_every_line_priced(small)
  end

  test "permits: structural engineering add-on" do
    result = generate("permits", {
      permitType:             "structural",
      projectCost:            150_000,
      structuralEngineering:  true,
    })
    assert result[:material_list].any? { |l| l[:item] == "Structural Engineering" }
  end

  test "permits: zero project cost returns empty" do
    result = generate("permits", { projectCost: 0 })
    assert_empty result[:material_list]
  end

  # --- Site Prep ------------------------------------------------------------

  test "site_prep: excavation + clearing priced" do
    result = generate("site_prep", { excavationSqft: 500, siteClearingSqft: 1000 })
    assert result[:material_list].any? { |l| l[:item] == "Excavation" }
    assert result[:material_list].any? { |l| l[:item] == "Site Clearing" }
    assert result[:labor_hours] > 0
    assert_every_line_priced(result)
  end

  test "site_prep: zero values return empty" do
    result = generate("site_prep", { excavationSqft: 0, siteClearingSqft: 0 })
    assert_empty result[:material_list]
  end

  private

  def assert_every_line_priced(result)
    result[:material_list].each do |line|
      next if line[:category] == "Labor"
      assert line[:total_cost] > 0, "expected priced line, got #{line.inspect}"
      assert line[:source].present?, "expected source tag on #{line[:item]}"
    end
  end
end
