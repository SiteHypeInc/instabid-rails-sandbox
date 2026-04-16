require "test_helper"

class MaterialPriceTest < ActiveSupport::TestCase
  test "price_delta returns nil when no previous_price" do
    mp = MaterialPrice.new(price: 44.99)
    assert_nil mp.price_delta
  end

  test "price_delta returns difference when previous_price present" do
    mp = MaterialPrice.new(price: 44.99, previous_price: 40.00)
    assert_in_delta 4.99, mp.price_delta.to_f, 0.01
  end

  test "price_delta_pct calculates percentage" do
    mp = MaterialPrice.new(price: 44.00, previous_price: 40.00)
    assert_in_delta 10.0, mp.price_delta_pct, 0.1
  end

  test "price_delta is negative when price dropped" do
    mp = MaterialPrice.new(price: 38.00, previous_price: 44.99)
    assert mp.price_delta.to_f.negative?
  end

  test "requires sku and zip_code" do
    mp = MaterialPrice.new(price: 10.00)
    assert_not mp.valid?
    assert mp.errors[:sku].present?
    assert mp.errors[:zip_code].present?
  end
end
