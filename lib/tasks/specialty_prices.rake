namespace :specialty_prices do
  desc "Load the 41 TEA-213 specialty gap-list rows into material_prices"
  task load: :environment do
    results = SpecialtyPriceLoaderService.load

    by_status = results.group_by(&:status).transform_values(&:count)
    puts "SpecialtyPriceLoaderService: #{results.count} rows processed"
    by_status.each { |status, n| puts "  #{status}: #{n}" }

    errored = results.select { |r| r.status == "error" }
    if errored.any?
      puts "\nErrors:"
      errored.each { |r| puts "  #{r.trade}/#{r.pricing_key}: #{r.error}" }
    end

    # Summary: trade counts
    by_trade = results.group_by(&:trade).transform_values(&:count)
    puts "\nBy trade:"
    by_trade.each { |trade, n| puts "  #{trade}: #{n}" }
  end
end
