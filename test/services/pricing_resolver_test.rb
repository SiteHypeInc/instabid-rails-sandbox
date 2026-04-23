require "test_helper"

class PricingResolverTest < ActiveSupport::TestCase
  test "returns the supplied default when no DB layer exists" do
    assert_equal 44.96,
                 PricingResolver.price(trade: "roofing", key: "mat_arch", default: 44.96)
  end

  test "ignores contractor_id today (fallback-only implementation)" do
    assert_equal 40.00,
                 PricingResolver.price(
                   trade:         "roofing",
                   key:           "mat_asphalt",
                   contractor_id: 1,
                   default:       40.00
                 )
  end
end
