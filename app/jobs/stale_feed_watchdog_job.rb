require "net/http"
require "json"

# TEA-329 D3 — Stale-feed watchdog.
#
# Runs daily on the recurring schedule. Reads the freshest fetched_at across
# `material_prices`. If nothing has been fetched in N days (default 3, since
# the daily cron already runs nightly — two missed runs is the right alarm),
# pings Commander by creating a Paperclip issue assigned to them.
#
# Threshold ENV: STALE_FEED_THRESHOLD_DAYS (default 3).
#
# Alerting requires the following ENV (so the rails-sandbox container can post
# back to the control plane). Missing env = log-only mode (job still runs and
# reports, but no Paperclip issue is created):
#   PAPERCLIP_API_URL
#   PAPERCLIP_API_KEY
#   PAPERCLIP_COMPANY_ID
#   PAPERCLIP_COMMANDER_AGENT_ID
class StaleFeedWatchdogJob < ApplicationJob
  queue_as :default

  DEFAULT_THRESHOLD_DAYS = 3

  Result = Struct.new(:state, :last_fetched_at, :age_days, :threshold_days, :alert_issue_identifier, keyword_init: true)

  def perform
    threshold_days = (ENV["STALE_FEED_THRESHOLD_DAYS"].presence || DEFAULT_THRESHOLD_DAYS).to_i
    last_fetched   = MaterialPrice.where.not(fetched_at: nil).maximum(:fetched_at)

    if last_fetched.nil?
      log "No material_prices.fetched_at on record — treating as stale"
      result = create_alert!(reason: "material_prices is empty (no fetched_at on any row)", threshold_days: threshold_days)
      return result
    end

    age_seconds = Time.current - last_fetched
    age_days    = (age_seconds / 86_400.0).round(2)

    if age_seconds <= threshold_days * 86_400
      log "Feed is fresh: last_fetched_at=#{last_fetched.iso8601}, age=#{age_days}d, threshold=#{threshold_days}d"
      return Result.new(state: "fresh", last_fetched_at: last_fetched, age_days: age_days, threshold_days: threshold_days)
    end

    log "Feed is STALE: last_fetched_at=#{last_fetched.iso8601}, age=#{age_days}d, threshold=#{threshold_days}d"
    create_alert!(
      reason:           "material_prices.fetched_at MAX is #{age_days} days old (threshold #{threshold_days}d). Daily MaterialPriceRefreshJob has likely failed.",
      threshold_days:   threshold_days,
      last_fetched_at:  last_fetched,
      age_days:         age_days
    )
  end

  private

  def create_alert!(reason:, threshold_days:, last_fetched_at: nil, age_days: nil)
    api_url      = ENV["PAPERCLIP_API_URL"].to_s.strip
    api_key      = ENV["PAPERCLIP_API_KEY"].to_s.strip
    company_id   = ENV["PAPERCLIP_COMPANY_ID"].to_s.strip
    commander_id = ENV["PAPERCLIP_COMMANDER_AGENT_ID"].to_s.strip

    if [ api_url, api_key, company_id, commander_id ].any?(&:empty?)
      log "Paperclip alerting env not set — skipping issue creation. Reason: #{reason}"
      return Result.new(
        state:           "stale_log_only",
        last_fetched_at: last_fetched_at,
        age_days:        age_days,
        threshold_days:  threshold_days
      )
    end

    body = build_issue_body(reason: reason, last_fetched_at: last_fetched_at, age_days: age_days, threshold_days: threshold_days)
    payload = {
      title:            "Stale BigBox feed — #{(age_days || "n/a")}d since last fetch",
      description:      body,
      priority:         "high",
      status:           "todo",
      assigneeAgentId:  commander_id
    }

    response = post_paperclip(api_url, api_key, "/api/companies/#{company_id}/issues", payload)
    if response.is_a?(Net::HTTPSuccess)
      identifier = JSON.parse(response.body).fetch("identifier", "?")
      log "Created Paperclip alert issue #{identifier}"
      Result.new(
        state:                   "stale_alerted",
        last_fetched_at:         last_fetched_at,
        age_days:                age_days,
        threshold_days:          threshold_days,
        alert_issue_identifier:  identifier
      )
    else
      log "Paperclip issue create failed: HTTP #{response.code} — #{response.body[0, 300]}"
      Result.new(
        state:           "stale_alert_failed",
        last_fetched_at: last_fetched_at,
        age_days:        age_days,
        threshold_days:  threshold_days
      )
    end
  end

  def build_issue_body(reason:, last_fetched_at:, age_days:, threshold_days:)
    <<~MD
      ## Stale BigBox feed detected

      **Reason:** #{reason}

      - last_fetched_at: #{last_fetched_at&.iso8601 || "(none)"}
      - age: #{age_days || "n/a"} days
      - threshold: #{threshold_days} days
      - host: #{ENV["RAILS_HOST"].presence || "instabid-rails-sandbox"}

      ## Action

      The daily `MaterialPriceRefreshJob` (09:00 UTC) is the upstream signal. Check its run log and BigBox API health.

      Auto-filed by `StaleFeedWatchdogJob` (TEA-329 D3).
    MD
  end

  def post_paperclip(api_url, api_key, path, payload)
    uri = URI.join(api_url, path)
    req = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json", "Authorization" => "Bearer #{api_key}")
    req.body = payload.to_json
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
      http.request(req)
    end
  end

  def log(msg)
    Rails.logger.info("[StaleFeedWatchdogJob] #{msg}")
  end
end
