namespace :pricing do
  desc "TEA-344: fail the build when priced coverage <95% or median price freshness >48h. Thresholds in config/pricing_health.yml."
  task gate: :environment do
    config = PricingGate.load_config(Rails.env)
    metrics = PricingGate.compute(window_hours: config.fetch("freshness_window_hours"))

    coverage_ok  = metrics[:priced_coverage] >= config.fetch("priced_coverage_min")
    freshness_ok = metrics[:median_freshness_hours].nil? ||
                   metrics[:median_freshness_hours] <= config.fetch("median_freshness_hours_max")

    line = format(
      "pricing:gate priced_coverage=%.4f (min %.2f) median_freshness_hours=%s (max %d) total_skus=%d priced_skus=%d",
      metrics[:priced_coverage],
      config.fetch("priced_coverage_min"),
      metrics[:median_freshness_hours].nil? ? "n/a" : format("%.2f", metrics[:median_freshness_hours]),
      config.fetch("median_freshness_hours_max"),
      metrics[:total_skus],
      metrics[:priced_skus]
    )
    puts line

    if coverage_ok && freshness_ok
      puts "pricing:gate PASS"
      exit 0
    else
      reasons = []
      reasons << "priced_coverage<#{config.fetch('priced_coverage_min')}" unless coverage_ok
      reasons << "median_freshness_hours>#{config.fetch('median_freshness_hours_max')}" unless freshness_ok
      puts "pricing:gate FAIL — #{reasons.join(', ')}"
      exit 1
    end
  end

  module PricingGate
    module_function

    def load_config(env)
      raw = YAML.load_file(Rails.root.join("config/pricing_health.yml"), aliases: true)
      raw[env.to_s] || raw["default"]
    end

    def compute(window_hours:)
      total = CatalogSku.count
      cutoff = window_hours.hours.ago

      priced_skus = MaterialPrice
                      .where("fetched_at >= ?", cutoff)
                      .where(sku: CatalogSku.select(:sku))
                      .distinct
                      .pluck(:sku)
                      .size

      newest_per_sku_hours = MaterialPrice
                               .where(sku: CatalogSku.select(:sku))
                               .where.not(fetched_at: nil)
                               .group(:sku)
                               .maximum(:fetched_at)
                               .values
                               .map { |t| (Time.current - t) / 3600.0 }

      coverage = total.zero? ? 0.0 : (priced_skus.to_f / total)

      {
        total_skus: total,
        priced_skus: priced_skus,
        priced_coverage: coverage,
        median_freshness_hours: median(newest_per_sku_hours)
      }
    end

    def median(values)
      return nil if values.empty?
      sorted = values.sort
      mid = sorted.size / 2
      sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
    end
  end
end
