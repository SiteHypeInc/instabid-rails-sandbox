require "test_helper"

class SpecialtyPriceLoaderServiceTest < ActiveSupport::TestCase
  test "loads all 41 specialty rows from docs/tea-203 JSON files" do
    results = SpecialtyPriceLoaderService.load

    assert_equal 41, results.count, "expected 41 rows across 8 trades"
    assert results.all? { |r| %w[created updated].include?(r.status) }, "no errors expected"

    by_trade = results.group_by(&:trade).transform_values(&:count)
    assert_equal({
      "cabinets"   => 17,
      "siding"     => 7,
      "painting"   => 6,
      "hvac"       => 4,
      "drywall"    => 2,
      "roofing"    => 2,
      "electrical" => 2,
      "plumbing"   => 1
    }, by_trade)
  end

  test "tags source and confidence; stores range and midpoint" do
    SpecialtyPriceLoaderService.load

    row = MaterialPrice.find_by(sku: "plumb_ball_valve_half", zip_code: "national")
    assert_not_nil row
    assert_equal "web_search_range", row.source
    assert_equal "medium",           row.confidence
    assert_equal "plumbing",         row.trade
    assert_equal 8.to_d,             row.price_low
    assert_equal 18.to_d,            row.price_high
    assert_equal 13.to_d,            row.price, "price should be midpoint of low/high"
    assert_equal "research_suggested", row.raw_response["source"]
  end

  test "rerun is idempotent (find_or_initialize_by)" do
    first  = SpecialtyPriceLoaderService.load
    second = SpecialtyPriceLoaderService.load

    assert first.all?  { |r| r.status == "created" }
    assert second.all? { |r| r.status == "updated" }
    assert_equal 41, MaterialPrice.where(source: "web_search_range").count
  end
end
