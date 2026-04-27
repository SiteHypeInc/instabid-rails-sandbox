require "test_helper"

class ServiceAreaZipTest < ActiveSupport::TestCase
  def teardown
    ServiceAreaZip.reload!
  end

  test "loads 5 service-area zips spanning US regions" do
    assert_equal 5, ServiceAreaZip.zips.size
    assert_equal %w[98101 80202 60601 30303 02108], ServiceAreaZip.codes
  end

  test "exposes city, state, region for each zip" do
    seattle = ServiceAreaZip.find("98101")
    assert_equal "Seattle", seattle.city
    assert_equal "WA",      seattle.state
    assert_equal "pacific_nw", seattle.region
  end

  test "find returns nil for unknown zip" do
    assert_nil ServiceAreaZip.find("99999")
  end

  test "regions are distinct so BigBox returns region-distinct pricing" do
    regions = ServiceAreaZip.zips.map(&:region).uniq
    assert_equal 5, regions.size, "all 5 zips must be in distinct regions"
  end
end
