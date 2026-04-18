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

    # POST — probe multiple BigBox Collections create patterns
    def collections_create_test
      api_key      = ENV["BIGBOX_API_KEY"].to_s.strip
      webhook_url  = params[:webhook_url].presence || "https://instabid-rails-sandbox-production.up.railway.app/webhooks/bigbox"
      test_sku     = params[:sku].presence || "202534215"
      probe_style  = params[:style].presence || "json_query"  # json_query | form_query | request_endpoint

      return render json: { error: "BIGBOX_API_KEY not set" }, status: :service_unavailable if api_key.blank?

      http_status, response_body = case probe_style
      when "json_query"
        # api_key in query string, JSON body (no api_key in body)
        uri       = URI(BIGBOX_COLLECTIONS_URL)
        uri.query = URI.encode_www_form(api_key: api_key)
        http      = build_http(uri)
        body      = { name: "instabid-#{Time.now.to_i}", requests: [{ type: "product", item_id: test_sku }] }.to_json
        req       = Net::HTTP::Post.new(uri.request_uri)
        req["Content-Type"] = "application/json"
        req.body = body
        r = http.request(req)
        [r.code.to_i, r.body]

      when "json_body"
        # api_key in JSON body
        uri  = URI(BIGBOX_COLLECTIONS_URL)
        http = build_http(uri)
        body = { api_key: api_key, name: "instabid-#{Time.now.to_i}", requests: [{ type: "product", item_id: test_sku }] }.to_json
        req  = Net::HTTP::Post.new(uri.request_uri)
        req["Content-Type"] = "application/json"
        req.body = body
        r = http.request(req)
        [r.code.to_i, r.body]

      when "form_query"
        # api_key in query, form-encoded body
        uri       = URI(BIGBOX_COLLECTIONS_URL)
        uri.query = URI.encode_www_form(api_key: api_key)
        http      = build_http(uri)
        req       = Net::HTTP::Post.new(uri.request_uri)
        req["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(name: "instabid-#{Time.now.to_i}")
        r = http.request(req)
        [r.code.to_i, r.body]

      when "request_endpoint"
        # try type=collections_create via /request endpoint
        uri       = URI(BIGBOX_BASE_URL)
        uri.query = URI.encode_www_form(api_key: api_key, type: "collections_create",
                                        name: "instabid-#{Time.now.to_i}")
        http      = build_http(uri)
        r = http.request(Net::HTTP::Get.new(uri.request_uri))
        [r.code.to_i, r.body]
      end

      render json: {
        probe_style:    probe_style,
        http_status:    http_status,
        top_level_keys: (JSON.parse(response_body).keys rescue ["parse_error"]),
        raw:            response_body
      }
    rescue => e
      render json: { error: e.class.to_s, message: e.message }
    end

    private

    def build_http(uri)
      http              = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.open_timeout = 12
      http.read_timeout = 12
      http
    end

    public

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
