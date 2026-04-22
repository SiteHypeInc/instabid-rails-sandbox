module Admin
  # POST /admin/pricing/collection         — create production collection (89 SKUs)
  # GET  /admin/pricing/collection/status  — list all BigBox collections
  # POST /admin/pricing/collection/ingest  — pull results and upsert to material_prices
  #
  class BigboxCollectionsController < ActionController::Base
    protect_from_forgery with: :null_session

    # POST /admin/pricing/collection
    # Creates (or re-creates) the instabid-materials-v1 collection with all 89 SKUs.
    # Optional params: schedule (default: daily), notify_email
    def create
      collection_id = BigboxCollectionService.create_production_collection(
        schedule:     params[:schedule].presence || "manual",
        notify_email: params[:notify_email].presence || "john@sitehypedesigns.com"
      )

      render json: {
        status:        "created",
        collection_id: collection_id,
        next_steps: [
          "1. Open BigBox UI → Collections → #{collection_id}",
          "2. Set webhook URL: #{request.base_url}/webhooks/bigbox",
          "3. Click 'Run Now' in BigBox UI to trigger first scrape",
          "4. Wait for BigBox to finish, then POST /admin/pricing/collection/ingest?collection_id=#{collection_id}",
          "   OR wait for the daily schedule to run automatically"
        ]
      }
    rescue => e
      render json: { error: e.class.to_s, message: e.message }, status: :unprocessable_entity
    end

    # GET /admin/pricing/collection/status
    def status
      data = BigboxCollectionService.new.list_collections

      collections = Array(data["collections"]).map do |c|
        {
          id:            c["id"],
          name:          c["name"],
          status:        c["status"],
          last_run:      c["last_run"],
          results_count: c["results_count"],
          sku_count:     c["requests_total_count"],
          schedule:      c["schedule_type"]
        }
      end

      render json: {
        total: data["total_count"],
        collections: collections
      }
    rescue => e
      render json: { error: e.class.to_s, message: e.message }, status: :unprocessable_entity
    end

    # POST /admin/pricing/collection/ingest?collection_id=XXXX&zip_code=10001
    # Pulls results from a completed collection and upserts to material_prices.
    def ingest
      collection_id = params[:collection_id].presence
      return render json: { error: "collection_id param required" }, status: :bad_request if collection_id.blank?

      zip_code = params[:zip_code].presence || "10001"

      results = BigboxCollectionService.ingest_results(
        collection_id: collection_id,
        zip_code:      zip_code
      )

      by_status = results.group_by(&:status)
      loaded    = by_status["loaded"] || []
      no_price  = by_status["no_price"] || []
      not_found = by_status["not_found"] || []
      transient = by_status["transient"] || []
      errors    = by_status["error"] || []

      render json: {
        collection_id: collection_id,
        zip_code:      zip_code,
        summary: {
          loaded:      loaded.count,
          no_price:    no_price.count,
          not_found:   not_found.count,
          transient:   transient.count,
          unknown_sku: (by_status["unknown_sku"] || []).count,
          no_product:  (by_status["no_product"] || []).count,
          no_result:   (by_status["no_results"] || []).count,
          errors:      errors.count,
          total:       results.count
        },
        loaded_prices: loaded.map { |r| { sku: r.sku, name: r.name, trade: r.trade, price: r.price, unit: r.unit } },
        transient_skus: transient.map { |r| r.sku },
        issues: (no_price + not_found + errors).map { |r| { sku: r.sku, name: r.name, status: r.status, error: r.error } }
      }
    rescue => e
      render json: { error: e.class.to_s, message: e.message }, status: :unprocessable_entity
    end
  end
end
