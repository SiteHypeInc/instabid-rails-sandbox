require "test_helper"

class MaterialListGeneratorBathTest < ActiveSupport::TestCase
  # TEA-240 Bath cluster: Vanity, Tile, Glass Enclosure, Shower System,
  # Waterproofing, Heated Floor. Covers Bath Standard + Shower-Focused Gut.

  def generate(trade, criteria)
    MaterialListGenerator.call(trade: trade, criteria: criteria, hourly_rate: 65)
  end

  # --- Vanity ---------------------------------------------------------------

  test "vanity: stock 30in baseline" do
    result = generate("vanity", { vanityType: "stock", vanityWidth: "30" })
    v = result[:material_list].find { |l| l[:item].start_with?("Vanity") }
    assert_equal 475.00, v[:unit_cost]
    assert_equal 3.0, result[:labor_hours]
  end

  test "vanity: custom 48in applies width-and-grade multiplier" do
    result = generate("vanity", { vanityType: "custom", vanityWidth: "48" })
    v = result[:material_list].find { |l| l[:item].start_with?("Vanity") }
    # 850 base × 2.4 custom = 2040
    assert_equal 2040.00, v[:unit_cost]
  end

  test "vanity: 60in double gets 5h labor" do
    result = generate("vanity", { vanityType: "stock", vanityWidth: "60" })
    assert_equal 5.0, result[:labor_hours]
  end

  test "vanity: recessed medicine cab adds labor" do
    surface = generate("vanity", { vanityType: "stock", vanityWidth: "30", medicineCabinet: "surface" })
    recessed = generate("vanity", { vanityType: "stock", vanityWidth: "30", medicineCabinet: "recessed" })
    assert recessed[:labor_hours] > surface[:labor_hours]
    assert recessed[:total_material_cost] > surface[:total_material_cost]
  end

  # --- Tile -----------------------------------------------------------------

  test "tile: bath standard with porcelain floor + full-height walls" do
    result = generate("tile", {
      floorTileMaterial: "porcelain",
      floorTileArea:     40,
      showerWallTile:    "full",
      showerSize:        "standard_36x36",
      tileComplexity:    "subway",
    })
    floor = result[:material_list].find { |l| l[:item].include?("Floor Tile") }
    assert_equal 7.25, floor[:unit_cost]
    assert_equal 40.0, floor[:quantity]
    wall = result[:material_list].find { |l| l[:item] == "Shower Wall Tile" }
    assert wall, "expected shower wall tile line"
    assert_every_line_priced(result)
  end

  test "tile: mosaic complexity multiplies labor vs standard" do
    std = generate("tile", { floorTileMaterial: "ceramic", floorTileArea: 40, tileComplexity: "standard" })
    mos = generate("tile", { floorTileMaterial: "ceramic", floorTileArea: 40, tileComplexity: "mosaic" })
    assert mos[:labor_hours] > std[:labor_hours]
  end

  test "tile: accent tile adds mosaic line + labor" do
    result = generate("tile", {
      floorTileMaterial: "ceramic",
      floorTileArea:     40,
      showerWallTile:    "full",
      showerSize:        "standard_36x36",
      accentTile:        true,
    })
    assert result[:material_list].any? { |l| l[:item].include?("Accent Tile") }
  end

  # --- Glass Enclosure ------------------------------------------------------

  test "glass: frameless is priciest tier" do
    framed   = generate("glass", { showerGlass: "framed" })
    semi     = generate("glass", { showerGlass: "semi-frameless" })
    frameless = generate("glass", { showerGlass: "frameless" })
    assert framed[:total_material_cost]  < semi[:total_material_cost]
    assert semi[:total_material_cost]    < frameless[:total_material_cost]
    assert_equal 3500.00, frameless[:total_material_cost]
  end

  test "glass: none returns empty" do
    result = generate("glass", { showerGlass: "none" })
    assert_equal 0.0, result[:total_material_cost]
  end

  # --- Shower System --------------------------------------------------------

  test "shower: spa multi-head with triple niche" do
    result = generate("shower", {
      showerSystem: "multi",
      showerNiche:  "triple",
    })
    sys = result[:material_list].find { |l| l[:item].include?("Shower System") }
    assert_equal 2250.00, sys[:unit_cost]
    niche = result[:material_list].find { |l| l[:item] == "Shower Niche" }
    assert_equal 3, niche[:quantity]
    assert_every_line_priced(result)
  end

  test "shower: single head minimum" do
    result = generate("shower", { showerSystem: "single" })
    assert_equal 425.00, result[:material_list].first[:unit_cost]
  end

  # --- Waterproofing --------------------------------------------------------

  test "waterproofing: priced per sqft with labor" do
    result = generate("waterproofing", { squareFeet: 60 })
    line = result[:material_list].find { |l| l[:item].include?("Waterproofing Membrane") }
    assert_equal 60.0, line[:quantity]
    assert_equal 8.50, line[:unit_cost]
    assert result[:labor_hours] > 0
    assert_every_line_priced(result)
  end

  test "waterproofing: zero sqft returns empty" do
    result = generate("waterproofing", { squareFeet: 0 })
    assert_empty result[:material_list]
  end

  # --- Heated Floor ---------------------------------------------------------

  test "heated_floor: mat + thermostat + labor" do
    result = generate("heated_floor", { heatedFloorSqft: 40 })
    items = result[:material_list].map { |l| l[:item] }
    assert items.any? { |i| i.include?("Heated Floor Mat") }
    assert items.any? { |i| i == "Programmable Thermostat" }
    assert_every_line_priced(result)
  end

  test "heated_floor: disabled flag returns empty" do
    result = generate("heated_floor", { heatedFloorSqft: 40, heatedFloor: false })
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
