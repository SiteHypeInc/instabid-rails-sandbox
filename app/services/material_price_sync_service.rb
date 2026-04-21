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
        config = config.with_indifferent_access

        # Fail-safe: entries without an explicit `syncable: true` are skipped.
        # Guards against BigBox silently overwriting multipliers, labor rates,
        # or lump sums if someone adds a new mapping without marking it.
        unless config[:syncable] == true
          results << SyncResult.new(
            trade: trade_name.to_s, pricing_key: pricing_key.to_s,
            before_value: current_value(trade_name.to_s, pricing_key.to_s),
            after_value: nil, material_value: nil, labor_adder: nil,
            sku_count: 0, skus: [], status: "skipped_not_syncable"
          )
          next
        end

        results << sync_one(
          trade:       trade_name.to_s,
          pricing_key: pricing_key.to_s,
          config:      config
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

    record = DefaultPricing.find_or_initialize_by(trade: trade, pricing_key: pricing_key)
    before = record.persisted? ? record.value : nil

    record.description  ||= config[:description]
    record.value          = new_value
    record.last_synced_at = Time.current
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
