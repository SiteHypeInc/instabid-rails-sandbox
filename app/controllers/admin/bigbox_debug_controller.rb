module Admin
  # GET /admin/pricing/debug_bigbox?term=Asphalt+Shingles
  #
  # Returns raw BigBox search API response for a single term.
  # Diagnostic only — remove before production.
  class BigboxDebugController < ActionController::Base
    protect_from_forgery with: :null_session

    BIGBOX_BASE_URL = "https://api.bigboxapi.com/request"

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
