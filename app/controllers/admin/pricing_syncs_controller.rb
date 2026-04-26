module Admin
  class PricingSyncsController < ActionController::Base
    protect_from_forgery with: :null_session

    PLUMBING_DEFAULTS = {
      "plumb_faucet_kitchen"   => { value: 300.00, description: "Kitchen faucet material cost (Jesse baseline)" },
      "plumb_sink_kitchen"     => { value: 550.00, description: "Kitchen sink material cost (Jesse baseline)" },
      "plumb_garbage_disposal" => { value: 325.00, description: "Garbage disposal material cost (Jesse baseline)" }
    }.freeze

    # POST /admin/pricing/seed
    # Seeds default_pricings with Jesse's baseline values.
    # Safe to call multiple times — uses find_or_create_by.
    def seed
      seeded = []

      PLUMBING_DEFAULTS.each do |pricing_key, attrs|
        record = DefaultPricing.find_or_create_by!(trade: "plumbing", pricing_key: pricing_key) do |r|
          r.value       = attrs[:value]
          r.description = attrs[:description]
        end
        seeded << { trade: "plumbing", pricing_key: pricing_key, value: record.value.to_f }
      end

      render json: { status: "seeded", rows: seeded }
    end

    SEED_FILE = Rails.root.join("config", "default_pricings_seed.yml")

    # POST /admin/pricing/seed_all
    # Upserts Jesse's baseline values across all 8 trades from config/default_pricings_seed.yml.
    # Idempotent — existing rows have value/description overwritten.
    def seed_all
      data = YAML.load_file(SEED_FILE)
      counts = Hash.new { |h, k| h[k] = { created: 0, updated: 0 } }

      data.each do |trade, keys|
        keys.each do |pricing_key, value|
          record = DefaultPricing.find_or_initialize_by(trade: trade, pricing_key: pricing_key)
          bucket = record.new_record? ? :created : :updated
          record.value = value
          record.description ||= "Jesse baseline (#{trade}/#{pricing_key})"
          record.save!
          counts[trade][bucket] += 1
        end
      end

      total = counts.values.sum { |c| c[:created] + c[:updated] }
      render json: { status: "seeded", total: total, by_trade: counts }
    end

    # POST /admin/pricing/sync
    # Runs MaterialPriceSyncService and returns before/after for each pricing key.
    def sync
      results = MaterialPriceSyncService.sync

      render json: {
        status:  "done",
        synced:  results.size,
        results: results.map do |r|
          {
            trade:        r.trade,
            pricing_key:  r.pricing_key,
            before:       r.before_value&.to_f,
            after:        r.after_value&.to_f,
            change:       r.before_value && r.after_value ? (r.after_value - r.before_value).to_f.round(2) : nil,
            material:     r.material_value&.to_f,
            labor_adder:  r.labor_adder&.to_f,
            sku_count:    r.sku_count,
            skus:         r.skus,
            status:       r.status
          }
        end
      }
    end

    # GET /admin/pricing/status
    # Shows current default_pricings rows.
    def status
      rows = DefaultPricing.order(:trade, :pricing_key).map do |r|
        {
          trade:          r.trade,
          pricing_key:    r.pricing_key,
          value:          r.value.to_f,
          description:    r.description,
          source:         r.source,
          last_synced_at: r.last_synced_at
        }
      end

      render json: { count: rows.size, rows: rows }
    end

    # GET /admin/pricing/probe?keys=trade:pricing_key,trade:pricing_key
    # TEA-327 diagnostic: dumps default_pricings.source + the actual
    # material_prices rows (sku, source, price, fetched_at) the sync would aggregate.
    # Read-only — no writes. Sandbox-only debug surface.
    def probe
      mappings = YAML.load_file(MaterialPriceSyncService::MAPPINGS_FILE).with_indifferent_access
      requested = params[:keys].to_s.split(",").map { |s| s.strip.split(":", 2) }.reject { |a| a.size != 2 }

      out = requested.map do |trade, key|
        dp     = DefaultPricing.find_by(trade: trade, pricing_key: key)
        cfg    = mappings.dig(trade, key) || {}
        skus   = Array(cfg[:skus]).map(&:to_s)
        rows   = MaterialPrice.where(sku: skus).map do |mp|
          { sku: mp.sku, source: mp.source, price: mp.price&.to_f, fetched_at: mp.fetched_at, name: mp.name }
        end
        {
          trade: trade, pricing_key: key,
          default_pricing: dp && {
            value:          dp.value.to_f,
            source:         dp.source,
            last_synced_at: dp.last_synced_at
          },
          mapped_skus:        skus,
          material_price_rows: rows
        }
      end

      render json: { count: out.size, results: out }
    end
  end
end
