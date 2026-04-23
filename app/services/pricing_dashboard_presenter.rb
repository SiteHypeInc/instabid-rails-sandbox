class PricingDashboardPresenter
  REFERENCE_FILE = Rails.root.join("config", "pricing_key_reference.yml")
  MAPPINGS_FILE  = Rails.root.join("config", "material_price_mappings.yml")

  TRADE_ORDER = %w[roofing siding electrical plumbing hvac painting drywall flooring].freeze
  TRADE_DISPLAY_NAMES = { "hvac" => "HVAC" }.freeze

  def initialize
    @reference     = YAML.load_file(REFERENCE_FILE).with_indifferent_access
    @mappings      = File.exist?(MAPPINGS_FILE) ? YAML.load_file(MAPPINGS_FILE).with_indifferent_access : {}.with_indifferent_access
    @defaults      = DefaultPricing.all.index_by { |dp| [ dp.trade, dp.pricing_key ] }
    @prices_by_sku = MaterialPrice.all.group_by(&:sku)
  end

  def trades
    TRADE_ORDER.filter_map do |key|
      next unless @reference[key]
      { key: key, name: display_name(key), icon: @reference[key][:icon] }
    end
  end

  def trade(trade_key)
    ref = @reference[trade_key]
    return nil unless ref

    sections = ref[:sections].map { |sec| build_section(trade_key, sec) }

    {
      key: trade_key,
      name: display_name(trade_key),
      icon: ref[:icon],
      sections: sections,
      total_keys: sections.sum { |s| s[:items].size },
      live_keys: sections.sum { |s| s[:items].count { |i| i[:bigbox_live] } },
      web_search_keys: sections.sum { |s| s[:items].count { |i| i[:web_search_live] } },
      populated_keys: sections.sum { |s| s[:items].count { |i| i[:has_value] } }
    }
  end

  private

  def display_name(key)
    TRADE_DISPLAY_NAMES[key] || key.humanize
  end

  def build_section(trade_key, sec)
    items = sec[:items].map { |item| build_item(trade_key, sec[:type], item) }
    {
      title:       sec[:title],
      type:        sec[:type],
      type_label:  sec[:type_label],
      syncable:    items.any? { |i| i[:bigbox_live] },
      items:       items
    }
  end

  def build_item(trade, type, item)
    key = item[:key]
    dp  = @defaults[[ trade, key ]]
    value = dp&.value&.to_f

    mapping  = @mappings.dig(trade, key)
    skus     = (mapping&.dig(:skus) || []).map(&:to_s)
    hd_rows  = skus.flat_map { |s| @prices_by_sku[s] || [] }
                   .select { |mp| mp.price.present? && mp.source.to_s.start_with?("bigbox") }

    # TEA-203: web_search rows use pricing_key as sku (no HD item_id). Surface
    # them as a fallback when BigBox has no match for this key. Same lookup
    # applies to specialty web_search_range rows.
    ws_rows  = (@prices_by_sku[key.to_s] || []).select do |mp|
      mp.price.present? && mp.source.to_s.start_with?("web_search")
    end

    material_part   = nil
    labor_part      = nil
    fetched_at      = nil
    price_source    = nil
    bigbox_live     = hd_rows.any?
    web_search_live = !bigbox_live && ws_rows.any?

    active_rows =
      if bigbox_live
        price_source = "bigbox"
        hd_rows
      elsif web_search_live
        price_source = ws_rows.first.source.to_s
        ws_rows
      else
        []
      end

    if active_rows.any?
      material_part = aggregate(active_rows.map { |r| r.price.to_f },
                                mapping&.dig(:aggregation) || "average")
      fetched_at    = active_rows.map(&:fetched_at).compact.max
      if type == "INSTALLED" && value
        labor_part = (value - material_part).round(2)
      end
    end

    {
      key:                key,
      label:              item[:label],
      unit:               item[:unit],
      value:              value,
      has_value:          value.present? || material_part.present?,
      description:        dp&.description || mapping&.dig(:description),
      last_synced_at:     dp&.last_synced_at,
      material_part:      material_part,
      labor_part:         labor_part,
      labor_adder_config: mapping&.dig(:labor_adder)&.to_f,
      bigbox_live:        bigbox_live,
      web_search_live:    web_search_live,
      price_source:       price_source,
      fetched_at:         fetched_at,
      hd_skus:            skus,
      web_search_sku:     web_search_live ? key.to_s : nil
    }
  end

  def aggregate(prices, strategy)
    return 0.0 if prices.empty?
    case strategy.to_s
    when "median"
      sorted = prices.sort
      mid = sorted.size / 2
      (sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0).to_f.round(2)
    when "min" then prices.min.to_f.round(2)
    when "max" then prices.max.to_f.round(2)
    else            (prices.sum / prices.size).to_f.round(2)
    end
  end
end
