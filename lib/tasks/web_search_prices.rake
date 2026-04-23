namespace :web_search_prices do
  desc "Load Road B (Tavily + Haiku) web_search price rows into material_prices"
  task load: :environment do
    results = WebSearchPriceLoaderService.load

    by_status = results.group_by(&:status).transform_values(&:count)
    puts "WebSearchPriceLoaderService: #{results.count} rows processed"
    by_status.each { |status, n| puts "  #{status}: #{n}" }

    errored = results.select { |r| r.status == "error" }
    if errored.any?
      puts "\nErrors:"
      errored.each { |r| puts "  #{r.trade}/#{r.pricing_key}: #{r.error}" }
    end

    by_trade_loaded = results
      .select { |r| %w[created updated].include?(r.status) }
      .group_by(&:trade)
      .transform_values(&:count)

    puts "\nLoaded by trade:"
    by_trade_loaded.each { |trade, n| puts "  #{trade}: #{n}" }
  end
end
