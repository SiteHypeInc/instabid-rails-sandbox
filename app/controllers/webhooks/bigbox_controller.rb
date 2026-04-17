module Webhooks
  class BigboxController < ActionController::Base
    # Skip CSRF — webhooks are server-to-server
    protect_from_forgery with: :null_session

    before_action :authenticate_bigbox!

    # POST /webhooks/bigbox
    def receive
      received_at = Time.current
      raw_body = request.body.read

      payload = parse_payload(raw_body)
      unless payload
        log_receipt(received_at: received_at, payload_bytes: raw_body.bytesize,
                    status: "error", error_summary: "Unparseable JSON payload")
        return render json: { error: "Invalid JSON" }, status: :unprocessable_entity
      end

      products = extract_products(payload)
      if products.empty?
        log_receipt(received_at: received_at, payload_bytes: raw_body.bytesize,
                    status: "error", error_summary: "No products found in payload")
        return render json: { error: "No products in payload" }, status: :unprocessable_entity
      end

      upserted = 0
      errors   = []

      products.each do |product|
        upsert_product(product)
        upserted += 1
      rescue => e
        errors << { sku: product["sku"], error: e.message }
        Rails.logger.warn("[BigboxWebhook] Failed to upsert product #{product['sku'].inspect}: #{e.message}")
      end

      status = if errors.empty?
        "success"
      elsif upserted > 0
        "partial"
      else
        "error"
      end

      error_summary = errors.any? ? errors.map { |e| "#{e[:sku]}: #{e[:error]}" }.join("; ") : nil

      log_receipt(
        received_at: received_at,
        payload_bytes: raw_body.bytesize,
        products_received: products.size,
        products_upserted: upserted,
        products_failed: errors.size,
        status: status,
        error_summary: error_summary
      )

      Rails.logger.info(
        "[BigboxWebhook] Received #{products.size} products — " \
        "upserted: #{upserted}, failed: #{errors.size}, status: #{status}"
      )

      render json: {
        received: products.size,
        upserted: upserted,
        failed: errors.size,
        status: status
      }, status: :ok
    end

    private

    def authenticate_bigbox!
      expected = ENV["BIGBOX_WEBHOOK_SECRET"].to_s.strip.gsub(/\s+/, "")

      if expected.blank?
        Rails.logger.error("[BigboxWebhook] BIGBOX_WEBHOOK_SECRET not set — rejecting all requests")
        return head :service_unavailable
      end

      received = request.headers["X-Bigbox-Secret"].to_s.strip

      unless ActiveSupport::SecurityUtils.secure_compare(expected, received)
        Rails.logger.warn("[BigboxWebhook] Auth failure from #{request.remote_ip}")
        head :unauthorized
      end
    end

    def parse_payload(raw_body)
      JSON.parse(raw_body)
    rescue JSON::ParserError
      nil
    end

    # BigBox may send:
    #   { "products": [...] }
    #   { "items": [...] }
    #   [ {...}, {...} ]  (root array)
    def extract_products(payload)
      case payload
      when Array
        payload
      when Hash
        payload["products"] || payload["items"] || payload["results"] || []
      else
        []
      end
    end

    def upsert_product(product)
      sku      = product["sku"].to_s.strip
      zip_code = product["zip_code"].presence || "national"

      raise ArgumentError, "missing sku" if sku.blank?

      record = MaterialPrice.find_or_initialize_by(sku: sku, zip_code: zip_code)

      new_price = product["price"].presence&.to_d

      # Capture previous price for delta tracking on updates
      if record.persisted? && new_price && record.price != new_price
        record.previous_price = record.price
      end

      record.assign_attributes(
        name:         product["title"] || product["name"],
        category:     product["category"],
        trade:        product["trade"],
        unit:         product["unit"],
        price:        new_price,
        source:       product["source"].presence || "bigbox",
        confidence:   product["confidence"].presence || "high",
        fetched_at:   parse_time(product["fetched_at"]) || Time.current,
        raw_response: product
      )

      record.save!
    end

    def parse_time(value)
      return nil if value.blank?

      Time.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def log_receipt(received_at:, payload_bytes:, products_received: 0,
                    products_upserted: 0, products_failed: 0,
                    status: "success", error_summary: nil)
      WebhookReceipt.create!(
        source:             "bigbox",
        received_at:        received_at,
        payload_bytes:      payload_bytes,
        products_received:  products_received,
        products_upserted:  products_upserted,
        products_failed:    products_failed,
        status:             status,
        error_summary:      error_summary,
        remote_ip:          request.remote_ip
      )
    rescue => e
      # Never let logging failure break the webhook response
      Rails.logger.error("[BigboxWebhook] Failed to write WebhookReceipt: #{e.message}")
    end
  end
end
