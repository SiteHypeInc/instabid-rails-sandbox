class MaterialPriceSyncService
  MAPPINGS_FILE = Rails.root.join("config", "material_price_mappings.yml")

  # Returned for each pricing key processed
  SyncResult = Struct.new(:trade, :pricing_key, :before_value, :after_value, :material_value, :labor_adder, :sku_count, :skus, :status, keyword_init: true)

  def self.sync(trade: nil)
    new(trade: trade).sync
  end

  def initialize(trade: nil)
    @trade_filter = trade&.to_s
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
        sku_count: 0, skus: [], status: "skipped_no_data"
      )
    end

    labor_adder    = config.fetch(:labor_adder, 0).to_d
    material_value = aggregate(prices, aggregation).round(2)
    new_value      = (material_value + labor_adder).round(2)
    skus           = scope.pluck(:sku)
    sources        = scope.pluck(:source).compact.uniq

    record = DefaultPricing.find_or_initialize_by(trade: trade, pricing_key: pricing_key)
    before = record.persisted? ? record.value : nil

    record.description  ||= config[:description]
    record.value          = new_value
    record.last_synced_at = Time.current
    record.source         = source_tag_for(sources)
    record.save!

    SyncResult.new(
      trade: trade, pricing_key: pricing_key,
      before_value: before, after_value: new_value,
      material_value: material_value, labor_adder: labor_adder,
      sku_count: skus.size, skus: skus, status: "updated"
    )
  end

  def current_value(trade, pricing_key)
    DefaultPricing.find_by(trade: trade, pricing_key: pricing_key)&.value
  end

  # Maps the raw MaterialPrice.source values used for this sync into a single
  # canonical default_pricings.source tag. The HD cohort includes sandbox_seed
  # (Apr 17 hand-load of real HD SKUs/prices) so a sync that pulls from any
  # mix of bigbox*/sandbox_seed rows lands as "bigbox_hd", not "mixed_sync".
  def source_tag_for(sources)
    return "bigbox_hd" if sources.empty?
    hd      = sources.select { |s| MaterialPrice.hd_live_source?(s) }
    non_hd  = sources - hd
    web     = non_hd.select { |s| s.to_s.start_with?("web") }
    other   = non_hd - web
    return "bigbox_hd"  if hd.any?  && web.empty? && other.empty?
    return "web_search" if web.any? && hd.empty?  && other.empty?
    "mixed_sync"
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
end
