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

    # POST /admin/pricing/sync
    # Runs MaterialPriceSyncService and returns before/after for each pricing key.
    #
    # Params:
    #   trade  — optional. Limit sync to a single trade (e.g. "plumbing").
    #   force  — optional, truthy to bypass the 50%/200% guardrail. Use only after
    #            reviewing guardrail-tripped warnings in the logs.
    def sync
      trade_param = params[:trade].presence
      force_param = ActiveModel::Type::Boolean.new.cast(params[:force])
      results     = MaterialPriceSyncService.sync(trade: trade_param, force: force_param)

      summary = results.each_with_object(Hash.new(0)) { |r, h| h[r.status] += 1 }

      render json: {
        status:  "done",
        forced:  force_param,
        synced:  results.size,
        summary: summary,
        results: results.map do |r|
          {
            trade:        r.trade,
            pricing_key:  r.pricing_key,
            before:       r.before_value&.to_f,
            after:        r.after_value&.to_f,
            change:       r.before_value && r.after_value ? (r.after_value - r.before_value).to_f.round(2) : nil,
            material:     r.material_value&.to_f,
            labor_adder:  r.labor_adder&.to_f,
            delta_ratio:  r.delta_ratio&.to_f,
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
          last_synced_at: r.last_synced_at
        }
      end

      render json: { count: rows.size, rows: rows }
    end
  end
end
