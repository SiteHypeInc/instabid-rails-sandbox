require "test_helper"

class WebSearchPriceLoaderServiceTest < ActiveSupport::TestCase
  test "loads rows with match_price and usable confidence; skips the rest" do
    results = WebSearchPriceLoaderService.load

    loaded  = results.select { |r| %w[created updated].include?(r.status) }
    skipped = results.select { |r| r.status == "skipped_no_price" }
    errored = results.select { |r| r.status == "error" }

    assert_empty errored, "no loader errors expected: #{errored.map(&:error)}"
    assert_operator loaded.count, :>=, 1, "at least one priced Road B row should be loadable"
    assert_operator skipped.count, :>=, 1, "null-price Road B rows should be flagged skipped_no_price"
  end

  test "tags source='web_search' and preserves confidence from Road B" do
    WebSearchPriceLoaderService.load

    sample = MaterialPrice.where(source: "web_search").first
    assert_not_nil sample, "expected at least one web_search row"
    assert_includes %w[high medium low], sample.confidence
    assert_operator sample.price.to_f, :>, 0
    assert sample.raw_response["pricing_key"].present?
  end

  test "is idempotent — a second run does not duplicate rows" do
    WebSearchPriceLoaderService.load
    first_count = MaterialPrice.where(source: "web_search").count

    WebSearchPriceLoaderService.load
    second_count = MaterialPrice.where(source: "web_search").count

    assert_equal first_count, second_count
  end
end
