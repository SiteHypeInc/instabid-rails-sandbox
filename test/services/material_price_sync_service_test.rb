require "test_helper"

# Tests the material_prices → default_pricings sync, including the 50%/200%
# guardrail added in TEA-158.
class MaterialPriceSyncServiceTest < ActiveSupport::TestCase
  # Mapping keys used by these tests (must exist in config/material_price_mappings.yml):
  #
  # roofing.mat_asphalt          — skus ["202534215"],                labor_adder 0
  # plumbing.plumb_faucet_kitchen — skus ["309847251"],               labor_adder 125
  # plumbing.plumb_garbage_disposal — categories ["garbage_disposals"], labor_adder 150
  # flooring.floor_laminate      — skus ["310562847","311847562"],    labor_adder 0

  ASPHALT_SKU      = "202534215"
  FAUCET_SKU       = "309847251"
  DISPOSAL_CAT     = "garbage_disposals"
  LAMINATE_AC3_SKU = "310562847"
  LAMINATE_AC4_SKU = "311847562"

  teardown do
    MaterialPrice.delete_all
    DefaultPricing.delete_all
  end

  # ── Happy path ──────────────────────────────────────────────────────────────

  test "first write creates default_pricings row with material + labor_adder" do
    seed_price(sku: FAUCET_SKU, trade: "plumbing", price: 275.00)

    results = MaterialPriceSyncService.sync(trade: "plumbing")
    faucet  = results.find { |r| r.pricing_key == "plumb_faucet_kitchen" }

    assert_equal "updated", faucet.status
    assert_nil   faucet.before_value
    assert_in_delta 400.00, faucet.after_value.to_f, 0.01   # 275 material + 125 labor
    assert_nil   faucet.delta_ratio                         # no existing value

    row = DefaultPricing.find_by!(trade: "plumbing", pricing_key: "plumb_faucet_kitchen")
    assert_in_delta 400.00, row.value.to_f, 0.01
    assert row.last_synced_at.present?
  end

  test "labor_adder of 0 passes material price through untouched" do
    seed_price(sku: ASPHALT_SKU, trade: "roofing", price: 34.97)

    results = MaterialPriceSyncService.sync(trade: "roofing")
    asphalt = results.find { |r| r.pricing_key == "mat_asphalt" }

    assert_equal "updated", asphalt.status
    assert_in_delta 34.97, asphalt.after_value.to_f, 0.01
    assert_in_delta 34.97, asphalt.material_value.to_f, 0.01
    assert_equal 0.to_d, asphalt.labor_adder
  end

  test "category-based lookup resolves via category when no sku match" do
    # plumb_garbage_disposal uses categories: ["garbage_disposals"]
    seed_price(sku: "999999991", trade: "plumbing", category: DISPOSAL_CAT, price: 120.00)
    seed_price(sku: "999999992", trade: "plumbing", category: DISPOSAL_CAT, price: 180.00)

    results  = MaterialPriceSyncService.sync(trade: "plumbing")
    disposal = results.find { |r| r.pricing_key == "plumb_garbage_disposal" }

    assert_equal "updated", disposal.status
    assert_in_delta 150.00, disposal.material_value.to_f, 0.01   # average(120,180)
    assert_in_delta 300.00, disposal.after_value.to_f,    0.01   # 150 + 150 labor
    assert_equal 2, disposal.sku_count
  end

  test "averages multiple skus" do
    # floor_laminate averages AC3 + AC4
    seed_price(sku: LAMINATE_AC3_SKU, trade: "flooring", price: 2.00)
    seed_price(sku: LAMINATE_AC4_SKU, trade: "flooring", price: 3.00)

    results  = MaterialPriceSyncService.sync(trade: "flooring")
    laminate = results.find { |r| r.pricing_key == "floor_laminate" }

    assert_equal "updated", laminate.status
    assert_in_delta 2.50, laminate.after_value.to_f, 0.01
  end

  # ── Idempotency ─────────────────────────────────────────────────────────────

  test "re-running sync with unchanged material_prices leaves value unchanged" do
    seed_price(sku: FAUCET_SKU, trade: "plumbing", price: 275.00)

    first  = MaterialPriceSyncService.sync(trade: "plumbing")
                 .find { |r| r.pricing_key == "plumb_faucet_kitchen" }
    second = MaterialPriceSyncService.sync(trade: "plumbing")
                 .find { |r| r.pricing_key == "plumb_faucet_kitchen" }

    assert_equal "updated", first.status
    assert_equal "updated", second.status
    assert_in_delta first.after_value.to_f, second.after_value.to_f, 0.01

    row = DefaultPricing.find_by!(trade: "plumbing", pricing_key: "plumb_faucet_kitchen")
    assert_in_delta 400.00, row.value.to_f, 0.01
  end

  # ── Guardrail ───────────────────────────────────────────────────────────────

  test "within-tolerance updates pass through" do
    DefaultPricing.create!(trade: "plumbing", pricing_key: "plumb_faucet_kitchen", value: 400.00)
    # new proposed value = 450 + 125 labor = 575. 575/400 = 1.4375, within [0.5, 2.0].
    seed_price(sku: FAUCET_SKU, trade: "plumbing", price: 450.00)

    results = MaterialPriceSyncService.sync(trade: "plumbing")
    faucet  = results.find { |r| r.pricing_key == "plumb_faucet_kitchen" }

    assert_equal "updated", faucet.status
    assert_in_delta 575.00, faucet.after_value.to_f, 0.01

    row = DefaultPricing.find_by!(trade: "plumbing", pricing_key: "plumb_faucet_kitchen")
    assert_in_delta 575.00, row.value.to_f, 0.01
  end

  test "guardrail trips when proposed value exceeds 200% of existing" do
    DefaultPricing.create!(trade: "roofing", pricing_key: "mat_asphalt", value: 30.00)
    # proposed = 100 (no labor), 100/30 = 3.33 → trip
    seed_price(sku: ASPHALT_SKU, trade: "roofing", price: 100.00)

    log_capture = capture_warn_log do
      results = MaterialPriceSyncService.sync(trade: "roofing")
      asphalt = results.find { |r| r.pricing_key == "mat_asphalt" }

      assert_equal "skipped_guardrail", asphalt.status
      assert_in_delta 30.00, asphalt.before_value.to_f, 0.01
      assert_nil asphalt.after_value
      assert asphalt.delta_ratio.to_f > 2.0
    end

    row = DefaultPricing.find_by!(trade: "roofing", pricing_key: "mat_asphalt")
    assert_in_delta 30.00, row.value.to_f, 0.01  # unchanged

    assert_match(/default_pricings\.guardrail_tripped/, log_capture)
    payload = extract_log_payload(log_capture)
    assert_equal "mat_asphalt",                   payload["pricing_key"]
    assert_equal "roofing",                       payload["trade"]
    assert_equal "skipped_pending_manual_review", payload["action"]
    assert_in_delta 30.0,  payload["existing_value"].to_f, 0.01
    assert_in_delta 100.0, payload["proposed_value"].to_f, 0.01
  end

  test "guardrail trips when proposed value falls below 50% of existing" do
    DefaultPricing.create!(trade: "roofing", pricing_key: "mat_asphalt", value: 30.00)
    # proposed = 10 → 10/30 = 0.33 → trip
    seed_price(sku: ASPHALT_SKU, trade: "roofing", price: 10.00)

    capture_warn_log do
      results = MaterialPriceSyncService.sync(trade: "roofing")
      asphalt = results.find { |r| r.pricing_key == "mat_asphalt" }

      assert_equal "skipped_guardrail", asphalt.status
      assert asphalt.delta_ratio.to_f < 0.5
    end

    row = DefaultPricing.find_by!(trade: "roofing", pricing_key: "mat_asphalt")
    assert_in_delta 30.00, row.value.to_f, 0.01  # unchanged
  end

  test "first write never trips guardrail" do
    # No existing default_pricings row → guardrail cannot apply.
    seed_price(sku: ASPHALT_SKU, trade: "roofing", price: 999.00)  # wildly high

    results = MaterialPriceSyncService.sync(trade: "roofing")
    asphalt = results.find { |r| r.pricing_key == "mat_asphalt" }

    assert_equal "updated", asphalt.status
    assert_in_delta 999.00, asphalt.after_value.to_f, 0.01
    assert_nil asphalt.delta_ratio
  end

  test "force: true bypasses guardrail and marks status updated_forced" do
    DefaultPricing.create!(trade: "roofing", pricing_key: "mat_asphalt", value: 30.00)
    seed_price(sku: ASPHALT_SKU, trade: "roofing", price: 100.00)  # would normally trip

    results = MaterialPriceSyncService.sync(trade: "roofing", force: true)
    asphalt = results.find { |r| r.pricing_key == "mat_asphalt" }

    assert_equal "updated_forced", asphalt.status
    assert_in_delta 100.00, asphalt.after_value.to_f, 0.01

    row = DefaultPricing.find_by!(trade: "roofing", pricing_key: "mat_asphalt")
    assert_in_delta 100.00, row.value.to_f, 0.01
  end

  test "borderline exactly-2x ratio is allowed (inclusive bound)" do
    DefaultPricing.create!(trade: "roofing", pricing_key: "mat_asphalt", value: 25.00)
    seed_price(sku: ASPHALT_SKU, trade: "roofing", price: 50.00)   # ratio = 2.0 exactly

    results = MaterialPriceSyncService.sync(trade: "roofing")
    asphalt = results.find { |r| r.pricing_key == "mat_asphalt" }

    assert_equal "updated", asphalt.status
    assert_in_delta 50.00, asphalt.after_value.to_f, 0.01
  end

  # ── No-data path ────────────────────────────────────────────────────────────

  test "skips with no_data when no material_prices rows match" do
    # No seeded prices at all.
    results = MaterialPriceSyncService.sync(trade: "roofing")
    asphalt = results.find { |r| r.pricing_key == "mat_asphalt" }

    assert_equal "skipped_no_data", asphalt.status
    assert_nil asphalt.after_value
    assert_equal 0, asphalt.sku_count
  end

  # ── Trade filter ────────────────────────────────────────────────────────────

  test "trade filter scopes sync to a single trade" do
    seed_price(sku: ASPHALT_SKU, trade: "roofing",  price: 35.00)
    seed_price(sku: FAUCET_SKU,  trade: "plumbing", price: 275.00)

    results = MaterialPriceSyncService.sync(trade: "roofing")

    assert results.all? { |r| r.trade == "roofing" }
    assert_nil DefaultPricing.find_by(trade: "plumbing", pricing_key: "plumb_faucet_kitchen")
  end

  private

  def seed_price(sku:, trade:, price:, category: nil, zip_code: "national")
    MaterialPrice.create!(
      sku: sku, zip_code: zip_code, trade: trade,
      category: category, price: price,
      source: "test", confidence: "high", fetched_at: Time.current
    )
  end

  # Captures Rails.logger.warn JSON output emitted during the block.
  def capture_warn_log
    io     = StringIO.new
    orig   = Rails.logger
    logger = ActiveSupport::Logger.new(io)
    logger.level = ::Logger::WARN
    Rails.logger = logger
    yield
    io.string
  ensure
    Rails.logger = orig
  end

  def extract_log_payload(log_string)
    line = log_string.lines.find { |l| l.include?("default_pricings.guardrail_tripped") }
    raise "no guardrail log line captured" unless line
    # Rails logger may prefix with timestamp / level; pull out the JSON object.
    json = line[/\{.*\}/m]
    JSON.parse(json)
  end
end
