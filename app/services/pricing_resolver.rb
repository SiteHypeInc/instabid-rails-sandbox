module PricingResolver
  # Unit-price lookup for a trade + snake_case pricing key.
  #
  # In Jesse's main repo this will resolve contractor_pricings -> default_pricings
  # -> regional multiplier. In this sandbox the DB layers may be partially
  # populated (DefaultPricing + MaterialPrice). We resolve in this order:
  #
  #   1. MaterialPrice row tagged bigbox*     → source "BigBox Live HD"
  #   2. MaterialPrice row tagged web_search* → source "Web Search"
  #   3. DefaultPricing row                   → source "Manual"
  #   4. caller-supplied default              → source "Manual"
  #
  # Signature is stable — swap the implementation when Jesse's full pricing
  # stack lands without touching callers.

  # Ordered longest-prefix-first so more specific labels win (e.g.
  # "web_search_range" must match before the bare "web_search" prefix).
  SOURCE_LABELS = [
    [ "web_search_range", "Web Search Range" ],
    [ "bigbox",           "BigBox Live HD"   ],
    [ "web_search",       "Web Search"       ],
    [ "manual",           "Manual"           ]
  ].freeze

  def self.price(trade:, key:, contractor_id: nil, default:)
    resolve(trade: trade, key: key, contractor_id: contractor_id, default: default)[:price]
  end

  def self.resolve(trade:, key:, contractor_id: nil, default:)
    _ = contractor_id

    if defined?(MaterialPrice) && MaterialPrice.table_exists?
      live = MaterialPrice.where(trade: trade.to_s, sku: key.to_s).where.not(price: nil).first
      if live
        return {
          price:      live.price.to_f,
          price_low:  live.respond_to?(:price_low)  ? live.price_low&.to_f  : nil,
          price_high: live.respond_to?(:price_high) ? live.price_high&.to_f : nil,
          source:     source_label_for(live.source),
          confidence: live.confidence.to_s
        }
      end
    end

    if defined?(DefaultPricing) && DefaultPricing.table_exists?
      dp = DefaultPricing.find_by(trade: trade.to_s, pricing_key: key.to_s)
      return { price: dp.value.to_f, price_low: nil, price_high: nil, source: "Manual", confidence: "high" } if dp&.value
    end

    { price: default, price_low: nil, price_high: nil, source: "Manual", confidence: "high" }
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    { price: default, price_low: nil, price_high: nil, source: "Manual", confidence: "high" }
  end

  def self.source_label_for(raw)
    return "Manual" if raw.blank?

    raw = raw.to_s.downcase
    SOURCE_LABELS.each { |prefix, label| return label if raw.start_with?(prefix) }
    raw.tr("_", " ").split.map(&:capitalize).join(" ")
  end
end
