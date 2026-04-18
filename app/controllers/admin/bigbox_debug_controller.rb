module Admin
  # GET  /admin/pricing/debug_bigbox?term=Asphalt+Shingles  — search probe
  # GET  /admin/pricing/debug_collections                    — probe Collections API
  # POST /admin/pricing/debug_collections                    — create test collection
  #
  # Diagnostic only — remove before production.
  class BigboxDebugController < ActionController::Base
    protect_from_forgery with: :null_session

    BIGBOX_BASE_URL       = "https://api.bigboxapi.com/request"
    BIGBOX_COLLECTIONS_URL = "https://api.bigboxapi.com/collections"

    # GET — probe Collections endpoint to learn API shape
    def collections_probe
      api_key = ENV["BIGBOX_API_KEY"].to_s.strip
      return render json: { error: "BIGBOX_API_KEY not set" }, status: :service_unavailable if api_key.blank?

      uri       = URI(BIGBOX_COLLECTIONS_URL)
      uri.query = URI.encode_www_form(api_key: api_key)

      http              = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.open_timeout = 10
      http.read_timeout = 10

      response = http.request(Net::HTTP::Get.new(uri.request_uri))

      render json: {
        http_status:    response.code.to_i,
        top_level_keys: (JSON.parse(response.body).keys rescue ["parse_error"]),
        raw:            response.body
      }
    rescue => e
      render json: { error: e.class.to_s, message: e.message }
    end

    # POST — create a test collection with 1 product SKU, return raw BigBox response
    def collections_create_test
      api_key      = ENV["BIGBOX_API_KEY"].to_s.strip
      webhook_url  = params[:webhook_url].presence || "https://instabid-rails-sandbox-production.up.railway.app/webhooks/bigbox"
      test_sku     = params[:sku].presence || "202534215"

      return render json: { error: "BIGBOX_API_KEY not set" }, status: :service_unavailable if api_key.blank?

      uri   = URI(BIGBOX_COLLECTIONS_URL)
      http  = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.open_timeout = 15
      http.read_timeout = 15

      # Attempt POST to create collection — body shape is a probe
      body = {
        api_key: api_key,
        name:    "instabid-test-#{Time.now.to_i}",
        webhook: webhook_url,
        requests: [
          { type: "product", item_id: test_sku }
        ]
      }.to_json

      req = Net::HTTP::Post.new(uri.path.presence || "/collections")
      req["Content-Type"] = "application/json"
      req.body = body

      response = http.request(req)

      render json: {
        http_status:    response.code.to_i,
        top_level_keys: (JSON.parse(response.body).keys rescue ["parse_error"]),
        raw:            response.body
      }
    rescue => e
      render json: { error: e.class.to_s, message: e.message }
    end

    def show
      term    = params[:term].presence || "Asphalt Shingles"
      zip     = params[:zip_code].presence || "10001"
      api_key = ENV["BIGBOX_API_KEY"].to_s.strip

      if api_key.blank?
        render json: { error: "BIGBOX_API_KEY not set" }, status: :service_unavailable
        return
      end

      uri       = URI(BIGBOX_BASE_URL)
      uri.query = URI.encode_www_form(
        api_key:     api_key,
        type:        "search",
        search_term: term,
        zip_code:    zip,
        page:        "1"
      )

      http              = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.open_timeout = 10
      http.read_timeout = 10

      response = http.request(Net::HTTP::Get.new(uri.request_uri))

      render json: {
        http_status: response.code.to_i,
        top_level_keys: (JSON.parse(response.body).keys rescue ["parse_error"]),
        raw: response.body
      }

    rescue => e
      render json: { error: e.class.to_s, message: e.message }
    end
  end
end
