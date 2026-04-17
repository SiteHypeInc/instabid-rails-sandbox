class MaterialPriceSyncService
  MAPPINGS_FILE = Rails.root.join("config", "material_price_mappings.yml")

  # Returned for each pricing key processed
  SyncResult = Struct.new(:trade, :pricing_key, :before_value, :after_value, :sku_count, :skus, :status, keyword_init: true)

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
    categories  = Array(config[:categories]).map(&:to_s)
    aggregation = config.fetch(:aggregation, "average").to_s

    scope  = MaterialPrice.where(category: categories).where.not(price: nil)
    prices = scope.pluck(:price)

    if prices.empty?
      return SyncResult.new(
        trade: trade, pricing_key: pricing_key,
        before_value: current_value(trade, pricing_key),
        after_value:  nil, sku_count: 0, skus: [], status: "skipped_no_data"
      )
    end

    new_value = aggregate(prices, aggregation).round(2)
    skus      = scope.pluck(:sku)

    record = DefaultPricing.find_or_initialize_by(trade: trade, pricing_key: pricing_key)
    before = record.persisted? ? record.value : nil

    record.description  ||= config[:description]
    record.value          = new_value
    record.last_synced_at = Time.current
    record.save!

    SyncResult.new(
      trade: trade, pricing_key: pricing_key,
      before_value: before, after_value: new_value,
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
