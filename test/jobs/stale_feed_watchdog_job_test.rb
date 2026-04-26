require "test_helper"

class StaleFeedWatchdogJobTest < ActiveSupport::TestCase
  setup do
    MaterialPrice.delete_all
    @env_keys = %w[STALE_FEED_THRESHOLD_DAYS PAPERCLIP_API_URL PAPERCLIP_API_KEY PAPERCLIP_COMPANY_ID PAPERCLIP_COMMANDER_AGENT_ID]
    @prior_env = @env_keys.to_h { |k| [ k, ENV[k] ] }
    @env_keys.each { |k| ENV.delete(k) }
  end

  teardown do
    @prior_env.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  test "fresh feed returns fresh state and does not alert" do
    MaterialPrice.create!(sku: "X1", trade: "roofing", source: "bigbox", price: 1.0, fetched_at: 1.hour.ago)

    result = StaleFeedWatchdogJob.new.perform

    assert_equal "fresh", result.state
    assert_equal 3, result.threshold_days
  end

  test "stale feed without paperclip env logs only" do
    MaterialPrice.create!(sku: "X2", trade: "roofing", source: "bigbox", price: 1.0, fetched_at: 5.days.ago)

    result = StaleFeedWatchdogJob.new.perform

    assert_equal "stale_log_only", result.state
    assert result.age_days > 3
  end

  test "empty material_prices is treated as stale" do
    result = StaleFeedWatchdogJob.new.perform

    assert_equal "stale_log_only", result.state
    assert_nil result.last_fetched_at
  end

  test "custom threshold is honored" do
    ENV["STALE_FEED_THRESHOLD_DAYS"] = "7"
    MaterialPrice.create!(sku: "X3", trade: "roofing", source: "bigbox", price: 1.0, fetched_at: 5.days.ago)

    result = StaleFeedWatchdogJob.new.perform

    assert_equal "fresh", result.state
    assert_equal 7, result.threshold_days
  end

  test "stale feed posts to paperclip when env is set" do
    ENV["PAPERCLIP_API_URL"]              = "https://example.test"
    ENV["PAPERCLIP_API_KEY"]              = "test_key"
    ENV["PAPERCLIP_COMPANY_ID"]           = "co-123"
    ENV["PAPERCLIP_COMMANDER_AGENT_ID"]   = "agent-cmd"
    MaterialPrice.create!(sku: "X4", trade: "roofing", source: "bigbox", price: 1.0, fetched_at: 10.days.ago)

    fake_response = Object.new
    def fake_response.is_a?(klass); klass == Net::HTTPSuccess; end
    def fake_response.body; '{"identifier":"TEA-999"}'; end

    captured = {}
    job = StaleFeedWatchdogJob.new
    job.define_singleton_method(:post_paperclip) do |url, key, path, payload|
      captured[:url]     = url
      captured[:key]     = key
      captured[:path]    = path
      captured[:payload] = payload
      fake_response
    end

    result = job.perform

    assert_equal "stale_alerted", result.state
    assert_equal "TEA-999", result.alert_issue_identifier
    assert_equal "/api/companies/co-123/issues", captured[:path]
    assert_equal "agent-cmd", captured[:payload][:assigneeAgentId]
    assert_equal "high", captured[:payload][:priority]
    assert_match(/Stale BigBox feed/, captured[:payload][:title])
  end
end
