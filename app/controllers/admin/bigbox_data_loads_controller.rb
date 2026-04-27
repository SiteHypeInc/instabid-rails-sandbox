module Admin
  # POST /admin/pricing/load
  #
  # Fetches all SKUs from BigBox API and upserts into material_prices.
  # Run this before POST /admin/pricing/sync so the sync has live data to work with.
  #
  # Params:
  #   trade:    optional — limit to one trade (e.g. "roofing")
  #   zip_code: required (TEA-345) — pick one of ServiceAreaZip.codes
  #
  # Requires BIGBOX_API_KEY env var.
  #
  # === DISABLED BY DEFAULT (TEA-157) ===
  # The underlying BigboxDataLoaderService is gated by ALLOW_BIGBOX_ONDEMAND.
  # When the flag is off, this endpoint returns 503 and does not hit BigBox.
  # The blessed writer for `material_prices` is the Collections webhook
  # receiver (Webhooks::BigboxController + BigboxCollectionService). Do not
  # flip this back on without deleting any residue it leaves in material_prices
  # first — see TEA-157 for the fingerprint query.
  class BigboxDataLoadsController < ActionController::Base
    protect_from_forgery with: :null_session

    def create
      trade    = params[:trade].presence
      zip_code = params[:zip_code].presence

      if zip_code.blank?
        return render json: {
          error: "zip_code param required",
          hint:  "Pick one of #{ServiceAreaZip.codes.inspect}"
        }, status: :bad_request
      end

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

    rescue BigboxDataLoaderService::OnDemandDisabledError => e
      render json: {
        error: e.message,
        hint:  "Set ALLOW_BIGBOX_ONDEMAND=true to re-enable. Prefer BigBox Collections (POST /admin/pricing/collection) instead."
      }, status: :service_unavailable
    rescue ArgumentError => e
      render json: { error: e.message }, status: :service_unavailable
    end
  end
end
