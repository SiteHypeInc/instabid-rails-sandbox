class MaterialPriceSyncService
  MAPPINGS_FILE = Rails.root.join("config", "material_price_mappings.yml")

  # Guardrail bounds applied per pricing key when an existing default_pricings row
  # exists. New values outside [GUARDRAIL_MIN_RATIO, GUARDRAIL_MAX_RATIO] × existing
  # value are NOT written. They are logged as structured warnings and returned with
  # status "skipped_guardrail" for manual review.
  #
  # Motivation: Laminate AC4 delivered a 96.4% price delta during sandbox validation.
  # Without a guardrail, a single BigBox anomaly or SKU swap can silently nuke a
  # default price that downstream contractor quotes depend on.
  #
  # Override: call with `force: true` after manual review to push a legitimate
  # out-of-band update through.
  GUARDRAIL_MIN_RATIO = 0.5
  GUARDRAIL_MAX_RATIO = 2.0

  # Returned for each pricing key processed
  SyncResult = Struct.new(
    :trade, :pricing_key, :before_value, :after_value, :material_value, :labor_adder,
    :sku_count, :skus, :delta_ratio, :status,
    keyword_init: true
  )

  def self.sync(trade: nil, force: false)
    new(trade: trade, force: force).sync
  end

  def initialize(trade: nil, force: false)
    @trade_filter = trade&.to_s
    @force        = force ? true : false
    @mappings     = YAML.load_file(MAPPINGS_FILE).with_indifferent_access
  end

  def sync
    results = []

    @mappings.each do |trade_name, keys|
      next if @trade_filter && @trade_filter != trade_name.to_s

      keys.each do |pricing_key, config|
        results << sync_one(
          trade:       trade_name.to_s,
          pricing_key: pricing_key.to_s,
          config:      config.with_indifferent_access
        )
      end
    end

    results
  end

  private

  def sync_one(trade:, pricing_key:, config:)
    skus        = Array(config[:skus]).map(&:to_s).reject(&:empty?)
    categories  = Array(config[:categories]).map(&:to_s).reject(&:empty?)
    aggregation = config.fetch(:aggregation, "average").to_s

    # skus: takes precedence; fall back to categories:
    scope = if skus.any?
      MaterialPrice.where(sku: skus)
    elsif categories.any?
      MaterialPrice.where(category: categories)
    else
      MaterialPrice.none
    end
    scope  = scope.where.not(price: nil)
    prices = scope.pluck(:price)

    if prices.empty?
      return SyncResult.new(
        trade: trade, pricing_key: pricing_key,
        before_value: current_value(trade, pricing_key),
        after_value: nil, material_value: nil, labor_adder: nil,
        sku_count: 0, skus: [], delta_ratio: nil, status: "skipped_no_data"
      )
    end

    labor_adder    = config.fetch(:labor_adder, 0).to_d
    material_value = aggregate(prices, aggregation).round(2)
    new_value      = (material_value + labor_adder).round(2)
    skus           = scope.pluck(:sku)

    record = DefaultPricing.find_or_initialize_by(trade: trade, pricing_key: pricing_key)
    before = record.persisted? ? record.value : nil
    ratio  = delta_ratio(before: before, proposed: new_value)

    if !@force && guardrail_trip?(before: before, ratio: ratio)
      log_guardrail_trip(
        trade: trade, pricing_key: pricing_key,
        before: before, proposed: new_value, ratio: ratio, skus: skus
      )
      return SyncResult.new(
        trade: trade, pricing_key: pricing_key,
        before_value: before, after_value: nil,
        material_value: material_value, labor_adder: labor_adder,
        sku_count: skus.size, skus: skus,
        delta_ratio: ratio, status: "skipped_guardrail"
      )
    end

    record.description  ||= config[:description]
    record.value          = new_value
    record.last_synced_at = Time.current
    record.save!

    status = @force && before && ratio && !in_tolerance?(ratio) ? "updated_forced" : "updated"

    SyncResult.new(
      trade: trade, pricing_key: pricing_key,
      before_value: before, after_value: new_value,
      material_value: material_value, labor_adder: labor_adder,
      sku_count: skus.size, skus: skus,
      delta_ratio: ratio, status: status
    )
  end

  def current_value(trade, pricing_key)
    DefaultPricing.find_by(trade: trade, pricing_key: pricing_key)&.value
  end

  def aggregate(prices, method)
    case method
    when "median" then median(prices)
    when "min"    then prices.min
    when "max"    then prices.max
    else               (prices.sum / prices.size)
    end
  end

  def median(values)
    sorted = values.sort
    mid    = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : ((sorted[mid - 1] + sorted[mid]) / 2.0)
  end

  def delta_ratio(before:, proposed:)
    return nil if before.nil? || before.zero? || proposed.nil?
    (proposed.to_d / before.to_d).round(4)
  end

  def in_tolerance?(ratio)
    ratio >= GUARDRAIL_MIN_RATIO && ratio <= GUARDRAIL_MAX_RATIO
  end

  def guardrail_trip?(before:, ratio:)
    return false if before.nil? || ratio.nil?
    !in_tolerance?(ratio)
  end

  def log_guardrail_trip(trade:, pricing_key:, before:, proposed:, ratio:, skus:)
    Rails.logger.warn({
      event:          "default_pricings.guardrail_tripped",
      trade:          trade,
      pricing_key:    pricing_key,
      existing_value: before.to_f,
      proposed_value: proposed.to_f,
      delta_ratio:    ratio.to_f,
      delta_pct:      ((ratio.to_f - 1.0) * 100).round(1),
      min_ratio:      GUARDRAIL_MIN_RATIO,
      max_ratio:      GUARDRAIL_MAX_RATIO,
      skus:           skus,
      action:         "skipped_pending_manual_review"
    }.to_json)
  end
end
