module Admin
  # POST /admin/pricing/load
  #
  # Fetches all SKUs from BigBox API and upserts into material_prices.
  # Run this before POST /admin/pricing/sync so the sync has live data to work with.
  #
  # Params (all optional):
  #   trade:    limit to one trade (e.g. "roofing")
  #   zip_code: HD regional pricing ZIP (default "10001")
  #
  # Requires BIGBOX_API_KEY env var.
  class BigboxDataLoadsController < ActionController::Base
    protect_from_forgery with: :null_session

    def create
      trade    = params[:trade].presence
      zip_code = params[:zip_code].presence || "10001"

      results = BigboxDataLoaderService.load(trade: trade, zip_code: zip_code)

      loaded  = results.count { |r| r.status == "loaded" }
      skipped = results.count { |r| r.status == "api_no_data" }
      errors  = results.select { |r| r.status == "error" }

      render json: {
        status:   errors.empty? ? "done" : "partial",
        loaded:   loaded,
        skipped:  skipped,
        failed:   errors.size,
        results:  results.map do |r|
          {
            sku:      r.sku,
            name:     r.name,
            trade:    r.trade,
            category: r.category,
            unit:     r.unit,
            price:    r.price&.to_f,
            status:   r.status,
            error:    r.error
          }
        end
      }

    rescue ArgumentError => e
      render json: { error: e.message }, status: :service_unavailable
    end
  end
end
