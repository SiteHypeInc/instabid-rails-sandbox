# TEA-329 D2 — Backfill default_pricings.source.
#
# Rule:
#   - last_synced_at IS NOT NULL → re-derive source from the mappings file +
#     current MaterialPrice rows for the row's trade/pricing_key. If the scope
#     resolves to a single source family, tag accordingly. If the scope is empty
#     today (live rows have rotated out) we still mark it bigbox_hd because
#     every sync run on this sandbox to date has been BigBox-fed.
#   - last_synced_at IS NULL → tag "manual". Every existing seed migration on
#     this sandbox prefixed its description with [Manual] and used hard-coded
#     values, so manual is the truthful tag.
#
# Ambiguous rows (synced but the mapping no longer exists, or a mix of source
# families in scope) are reported and left untagged. Per plan: don't guess.
#
# Idempotent: only writes when the computed tag differs from what's already there.

namespace :tea329 do
  desc "Backfill default_pricings.source"
  task backfill_default_pricing_source: :environment do
    mappings_path = Rails.root.join("config", "material_price_mappings.yml")
    mappings = YAML.load_file(mappings_path).with_indifferent_access

    counts = Hash.new(0)
    ambiguous = []

    DefaultPricing.find_each do |dp|
      tag =
        if dp.last_synced_at.nil?
          "manual"
        else
          mapping = mappings.dig(dp.trade, dp.pricing_key)
          if mapping.blank?
            nil
          else
            skus       = Array(mapping[:skus]).map(&:to_s).reject(&:empty?)
            categories = Array(mapping[:categories]).map(&:to_s).reject(&:empty?)
            scope =
              if skus.any?
                MaterialPrice.where(sku: skus)
              elsif categories.any?
                MaterialPrice.where(category: categories)
              else
                MaterialPrice.none
              end
            sources = scope.where.not(price: nil).pluck(:source).compact.uniq
            prefixes = sources.map { |s| s.to_s.split("_").first }.uniq

            case prefixes
            when []           then "bigbox_hd"           # synced but live rows rotated out
            when ["bigbox"]   then "bigbox_hd"
            when ["web"]      then "web_search"
            else                   nil                   # mixed/unknown → ambiguous
            end
          end
        end

      if tag.nil?
        ambiguous << "#{dp.trade}/#{dp.pricing_key} (last_synced_at=#{dp.last_synced_at})"
        counts[:ambiguous] += 1
        next
      end

      if dp.source == tag
        counts[:unchanged] += 1
      else
        dp.update_columns(source: tag, updated_at: Time.current)
        counts[tag.to_sym] += 1
      end
    end

    puts "TEA-329 backfill complete:"
    counts.sort.each { |k, v| puts "  #{k}: #{v}" }
    if ambiguous.any?
      puts ""
      puts "Ambiguous rows (left untagged — review and tag manually):"
      ambiguous.each { |row| puts "  - #{row}" }
    end
  end
end
