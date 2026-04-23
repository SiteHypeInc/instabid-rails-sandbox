namespace :tea236 do
  desc "Seed fixtures for the TEA-236 Test Estimate sandbox re-smoke (confidence=medium row + shared-material remodel)"
  task smoke_seeds: :environment do
    # 1) Confidence=medium material_price row. Exercises the
    #    web_search_range / pending-confidence render path that otherwise
    #    sits untouched by the default high-confidence bigbox seed.
    medium_row = MaterialPrice.find_or_initialize_by(sku: "plumbing.fixture_faucet_range", zip_code: "national")
    medium_row.assign_attributes(
      name:       "Faucet — mid-range estimate",
      category:   "Fixtures",
      trade:      "plumbing",
      unit:       "each",
      price:      262.00,
      source:     "web_search_range",
      confidence: "medium",
      fetched_at: Time.current
    )
    medium_row.save!
    puts "seeded medium-confidence row: #{medium_row.sku} @ $#{medium_row.price}"

    # 2) Shared-material 2-trade remodel fixture. "corner_bead" + "screws" are
    #    lines both drywall and siding emit during trim-out. Seed them so a
    #    remodel scope with drywall + siding checked exercises the dedup /
    #    join path without silently picking one trade's default.
    shared_keys = [
      {
        trade: "drywall", pricing_key: "corner_bead", description: "Corner bead 8ft (shared w/ siding trim-out)",
        value: 5.25
      },
      {
        trade: "siding", pricing_key: "corner_bead", description: "Corner bead 8ft (shared w/ drywall trim-out)",
        value: 5.25
      },
      {
        trade: "drywall", pricing_key: "screws", description: "Drywall/siding screws (shared)",
        value: 12.00
      },
      {
        trade: "siding", pricing_key: "screws", description: "Drywall/siding screws (shared)",
        value: 12.00
      }
    ]

    shared_keys.each do |attrs|
      dp = DefaultPricing.find_or_initialize_by(trade: attrs[:trade], pricing_key: attrs[:pricing_key])
      dp.assign_attributes(
        description:     attrs[:description],
        value:           attrs[:value],
        last_synced_at:  Time.current
      )
      dp.save!
      puts "seeded shared default: #{dp.trade}/#{dp.pricing_key} @ $#{dp.value}"
    end

    puts "\nTEA-236 smoke fixtures seeded. Re-run the 7-item smoke to verify."
  end
end
