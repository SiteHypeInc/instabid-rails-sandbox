module PricingResolver
  # Unit-price lookup for a trade + snake_case pricing key.
  #
  # Jesse's main repo will resolve contractor_pricings -> default_pricings ->
  # regional multiplier. Here we resolve default_pricings -> material_prices
  # (derived source) -> caller default. Signature is stable.
  #
  # `price` returns the numeric unit price (back-compat).
  # `price_with_source` returns { price:, source: } where source is one of
  # "BigBox Live HD" / "Web Search" / "Manual" / "Default" so downstream
  # callers (sandbox, dashboard) can surface the origin alongside the value.
  def self.price(trade:, key:, contractor_id: nil, default:)
    price_with_source(trade: trade, key: key, contractor_id: contractor_id, default: default)[:price]
  end

  def self.price_with_source(trade:, key:, contractor_id: nil, default:)
    _ = contractor_id
    dp = safe_default_pricing(trade, key)
    return { price: default, source: "Default" } unless dp

    mp = dominant_material_price(trade, key)
    source = derive_source(mp)
    { price: (dp.value.to_f.nonzero? || default), source: source }
  rescue => e
    Rails.logger.warn("[PricingResolver] lookup failed for #{trade}/#{key}: #{e.class} #{e.message}") if defined?(Rails)
    { price: default, source: "Default" }
  end

  def self.safe_default_pricing(trade, key)
    return nil unless defined?(DefaultPricing)
    DefaultPricing.find_by(trade: trade, pricing_key: key)
  end

  def self.dominant_material_price(trade, key)
    return nil unless defined?(MaterialPrice)
    # First check BigBox matches keyed by SKU via the mappings file; fall back
    # to web_search rows keyed by the pricing_key itself (TEA-203 convention).
    mappings = load_mappings
    skus     = (mappings.dig(trade, key, "skus") || mappings.dig(trade, key, :skus) || []).map(&:to_s)

    if skus.any?
      hd = MaterialPrice.where(sku: skus).where("source LIKE ?", "bigbox%").order(updated_at: :desc).first
      return hd if hd
    end
    MaterialPrice.where(sku: key.to_s).where("source LIKE ?", "web_search%").order(updated_at: :desc).first
  end

  def self.derive_source(material_price)
    return "Manual" unless material_price
    src = material_price.source.to_s
    return "BigBox Live HD" if src.start_with?("bigbox")
    return "Web Search"     if src.start_with?("web_search")
    "Manual"
  end

  def self.load_mappings
    @mappings ||= begin
      path = Rails.root.join("config", "material_price_mappings.yml") if defined?(Rails)
      path && File.exist?(path) ? YAML.load_file(path) : {}
    rescue
      {}
    end
  end
end
