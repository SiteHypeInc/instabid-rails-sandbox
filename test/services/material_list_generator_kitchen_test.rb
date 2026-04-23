require "test_helper"

class MaterialListGeneratorKitchenTest < ActiveSupport::TestCase
  # TEA-240 Kitchen cluster: Cabinets, Countertops, Backsplash, Appliances,
  # Demolition, Trim. Each builder produces itemized material_list with priced
  # lines, labor hours, and no [Builder not ported] rows.

  def generate(trade, criteria)
    MaterialListGenerator.call(trade: trade, criteria: criteria, hourly_rate: 65)
  end

  # --- Cabinets -------------------------------------------------------------

  test "cabinets: semi-custom Denver full-gut reference scenario" do
    result = generate("cabinets", {
      cabinetGrade:        "semi-custom",
      baseCabinetLf:       22,
      wallCabinetLf:       18,
      tallCabinets:        2,
      island:              "standard",
      cabinetHardware:     "mid-range",
      softCloseHinges:     true,
      softCloseDrawerSlides: true,
      crownMolding:        true,
      accessories:         ["Lazy Susan", "Pull-out Shelves"],
    })
    assert_equal "cabinets", result[:trade]
    assert result[:total_material_cost] > 10_000, "expected >$10k material, got #{result[:total_material_cost]}"
    assert result[:labor_hours] > 30, "expected >30 labor hours"
    items = result[:material_list].map { |l| l[:item] }
    assert items.any? { |i| i.include?("Base Cabinets") }
    assert items.any? { |i| i.include?("Wall Cabinets") }
    assert items.any? { |i| i.include?("Tall/Pantry") }
    assert items.any? { |i| i.include?("Pulls/Knobs") }
    assert items.any? { |i| i.include?("Soft-Close Hinges") }
    assert items.any? { |i| i.include?("Crown") }
    assert items.any? { |i| i.include?("Lazy Susan") }
    assert items.any? { |i| i.include?("Pull-Out Shelves") }
    assert_every_line_priced(result)
  end

  test "cabinets: custom grade uses cab_base_custom_lf" do
    result = generate("cabinets", {
      cabinetGrade:  "custom",
      baseCabinetLf: 20,
    })
    base_line = result[:material_list].find { |l| l[:item].start_with?("Base Cabinets") }
    assert_equal 600.00, base_line[:unit_cost]
  end

  test "cabinets: zero LF returns labor-only result" do
    result = generate("cabinets", { cabinetGrade: "stock" })
    assert_equal 0.0, result[:total_material_cost]
  end

  # --- Countertops ----------------------------------------------------------

  test "countertops: quartz auto-computes sqft from base LF" do
    result = generate("countertops", {
      countertopMaterial: "quartz",
      baseCabinetLf:      22,  # → 44 sqft auto
      edgeProfile:        "standard",
      sinkCutout:         true,
      cooktopCutout:      true,
    })
    qline = result[:material_list].find { |l| l[:item].include?("Countertop") }
    assert_equal 44.0, qline[:quantity]
    assert_equal 75.00, qline[:unit_cost]  # quartz default
    assert result[:total_material_cost] > 3_500, "expected >$3500 for 44 sqft quartz"
    assert result[:material_list].any? { |l| l[:item] == "Sink Cutout" }
    assert result[:material_list].any? { |l| l[:item] == "Cooktop Cutout" }
    assert_every_line_priced(result)
  end

  test "countertops: marble is priciest tier" do
    result = generate("countertops", { countertopMaterial: "marble", countertopSqft: 40 })
    line = result[:material_list].find { |l| l[:item].include?("Countertop") }
    assert_equal 120.00, line[:unit_cost]
  end

  # --- Backsplash -----------------------------------------------------------

  test "backsplash: subway auto-computes area from counter LF" do
    result = generate("backsplash", {
      backsplashType: "subway",
      baseCabinetLf:  22,  # → 33 sqft auto (LF × 1.5)
    })
    tline = result[:material_list].find { |l| l[:item].include?("Backsplash Tile") }
    assert_equal 33.0, tline[:quantity]
    assert result[:material_list].any? { |l| l[:item] == "Thinset Mortar" }
    assert result[:material_list].any? { |l| l[:item] == "Grout" }
    assert_every_line_priced(result)
  end

  test "backsplash: none returns empty" do
    result = generate("backsplash", { backsplashType: "none" })
    assert_equal 0.0, result[:total_material_cost]
    assert_empty result[:material_list]
  end

  test "backsplash: mosaic costs more labor than subway" do
    sub = generate("backsplash", { backsplashType: "subway", backsplashArea: 30 })
    mos = generate("backsplash", { backsplashType: "mosaic", backsplashArea: 30 })
    assert mos[:labor_hours] > sub[:labor_hours]
  end

  # --- Appliances -----------------------------------------------------------

  test "appliances: mid-range package with gas range" do
    result = generate("appliances", {
      appliancePackage: "mid-range",
      rangeType:        "gas",
      ventilation:      "wall-vented",
    })
    pkg = result[:material_list].find { |l| l[:item].include?("Appliance Package") }
    assert_equal 6500.00, pkg[:unit_cost]
    assert result[:material_list].any? { |l| l[:item].include?("Gas Line") }
    assert_every_line_priced(result)
  end

  test "appliances: reuse existing yields empty material" do
    result = generate("appliances", { appliancePackage: "reuse existing" })
    assert_equal 0.0, result[:total_material_cost]
  end

  test "appliances: roof-vented hood adds roof patch line" do
    result = generate("appliances", {
      appliancePackage: "premium",
      ventilation:      "roof-vented",
    })
    assert result[:material_list].any? { |l| l[:item].include?("Roof Penetration") }
  end

  # --- Demolition -----------------------------------------------------------

  test "demolition: full-gut kitchen at 200 sqft" do
    result = generate("demolition", {
      squareFeet:   200,
      remodelType:  "kitchen",
      scopePreset:  "full-gut",
    })
    demo = result[:material_list].find { |l| l[:item].start_with?("Demolition") }
    assert_equal 200.0, demo[:quantity]
    assert_equal 4.50, demo[:unit_cost]
    assert result[:material_list].any? { |l| l[:item] == "Dumpster Rental" }
    assert_every_line_priced(result)
  end

  test "demolition: cosmetic scope returns empty" do
    result = generate("demolition", {
      squareFeet:   200,
      remodelType:  "kitchen",
      scopePreset:  "cosmetic",
    })
    assert_empty result[:material_list]
  end

  test "demolition: pull-replace is half-rate" do
    full = generate("demolition", { squareFeet: 200, remodelType: "kitchen", scopePreset: "full-gut" })
    half = generate("demolition", { squareFeet: 200, remodelType: "kitchen", scopePreset: "pull-replace" })
    full_demo = full[:material_list].find { |l| l[:item].start_with?("Demolition") }[:total_cost]
    half_demo = half[:material_list].find { |l| l[:item].start_with?("Demolition") }[:total_cost]
    assert_in_delta full_demo * 0.5, half_demo, 0.01
  end

  # --- Trim -----------------------------------------------------------------

  test "trim: replace all trims baseboard + crown + door/window casings" do
    result = generate("trim", {
      trimAction:         "all",
      baseboardLf:        80,
      crownMoldingLf:     80,
      interiorDoorCount:  4,
      windowCasingCount:  3,
    })
    items = result[:material_list].map { |l| l[:item] }
    assert items.any? { |i| i == "Baseboard Trim" }
    assert items.any? { |i| i == "Crown Molding" }
    assert items.any? { |i| i.include?("Door Casing") }
    assert items.any? { |i| i.include?("Window Casing") }
    assert_every_line_priced(result)
  end

  test "trim: keep returns empty" do
    result = generate("trim", { trimAction: "keep" })
    assert_empty result[:material_list]
  end

  test "trim: replace_baseboard omits crown/door/window" do
    result = generate("trim", {
      trimAction:   "baseboard",
      baseboardLf:  80,
    })
    items = result[:material_list].map { |l| l[:item] }
    assert items.include?("Baseboard Trim")
    refute items.any? { |i| i == "Crown Molding" }
    refute items.any? { |i| i.include?("Casing") }
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
