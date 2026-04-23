require "test_helper"

# TEA-241: per-line `pricing_key` + `source` attribution on refactored trades
# (roofing, plumbing, electrical). Narrow assertions so future pricing-source
# label changes don't cascade — we only check that non-labor lines carry a
# snake_case pricing_key and a source from the allowed set.
class MaterialListGeneratorPricingKeyTest < ActiveSupport::TestCase
  ALLOWED_SOURCES = ["Manual", "BigBox Live HD", "Web Search", "Default"].freeze

  test "refactored roofing lines carry pricing_key and source per line" do
    result = MaterialListGenerator.call(
      trade:    "roofing",
      criteria: { squareFeet: 2000, material: "architectural", chimneys: 1, skylights: 1, valleys: 2, plywoodSqft: 320, ridgeVentFeet: 20 }
    )

    non_labor = result[:material_list].reject { |l| l[:category] == "Labor" }
    assert_predicate non_labor, :any?, "roofing should emit non-labor lines"

    non_labor.each do |line|
      assert_match(/\A[a-z0-9_]+\z/, line[:pricing_key].to_s,
                   "#{line[:item]} missing snake_case pricing_key; got #{line[:pricing_key].inspect}")
      assert_includes ALLOWED_SOURCES, line[:source],
                      "#{line[:item]} has unexpected source #{line[:source].inspect}"
    end
  end

  test "refactored plumbing lines carry pricing_key and source per line" do
    result = MaterialListGenerator.call(
      trade:    "plumbing",
      criteria: {
        serviceType: "repipe", squareFeet: 1800, bathrooms: 2, kitchens: 1, laundryRooms: 1,
        mainLineReplacement: "yes"
      }
    )

    non_labor = result[:material_list].reject { |l| l[:category] == "Labor" }
    assert_predicate non_labor, :any?, "plumbing should emit non-labor lines"

    non_labor.each do |line|
      assert_match(/\A[a-z0-9_]+\z/, line[:pricing_key].to_s,
                   "#{line[:item]} missing snake_case pricing_key; got #{line[:pricing_key].inspect}")
      assert_includes ALLOWED_SOURCES, line[:source],
                      "#{line[:item]} has unexpected source #{line[:source].inspect}"
    end
  end

  test "refactored electrical lines carry pricing_key and source per line (Equipment & Consumables excepted)" do
    result = MaterialListGenerator.call(
      trade:    "electrical",
      criteria: {
        serviceType: "circuits", squareFeet: 1800, homeAge: "1990+", stories: 1,
        outletCount: 6, gfciCount: 2, switchCount: 4, fixtureCount: 3, recessedCount: 4,
        circuits20a: 1, circuits30a: 1, evCharger: "yes"
      }
    )

    # "Equipment & Consumables" is a flat lot item with no underlying pricing_key;
    # stamp_sources still fills in `source` so the Source column renders. Labor
    # is also a flat rate, not resolver-backed.
    opt_out_items = ["Equipment & Consumables"].freeze
    non_labor = result[:material_list].reject { |l| l[:category] == "Labor" || opt_out_items.include?(l[:item]) }
    assert_predicate non_labor, :any?, "electrical should emit non-labor, non-lot lines"

    non_labor.each do |line|
      assert_match(/\A[a-z0-9_]+\z/, line[:pricing_key].to_s,
                   "#{line[:item]} missing snake_case pricing_key; got #{line[:pricing_key].inspect}")
      assert_includes ALLOWED_SOURCES, line[:source],
                      "#{line[:item]} has unexpected source #{line[:source].inspect}"
    end
  end

  test "un-refactored trade (drywall) still gets source via stamp_sources fallback" do
    # Phase 2 will refactor drywall and friends; until then stamp_sources must
    # keep filling `source` on every line so the Source column doesn't regress.
    result = MaterialListGenerator.call(
      trade:    "drywall",
      criteria: { squareFeet: 800, projectType: "new_construction", rooms: 3 }
    )

    result[:material_list].each do |line|
      assert_includes ALLOWED_SOURCES, line[:source],
                      "drywall line #{line[:item]} missing fallback source; got #{line[:source].inspect}"
    end
  end
end
