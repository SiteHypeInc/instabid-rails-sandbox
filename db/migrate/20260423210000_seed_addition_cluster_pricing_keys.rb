class SeedAdditionClusterPricingKeys < ActiveRecord::Migration[8.1]
  # TEA-240 Addition cluster seeds. All [Manual] defaults derived from TEA-238
  # spec ranges and typical retail/trade rates. HD Live / Web Search backfill
  # tracked separately.

  ADDITION_CLUSTER_SEEDS = [
    # --- Framing ---
    ["framing", "framing_wall_lf",      38.00, "[Manual] wall framing (2x6 studs + plates) — per LF"],
    ["framing", "framing_header_each", 145.00, "[Manual] framing header — each"],

    # --- Foundation ---
    ["foundation", "foundation_slab_sqft",       14.00, "[Manual] slab-on-grade foundation — per sqft"],
    ["foundation", "foundation_crawlspace_sqft", 18.00, "[Manual] crawlspace foundation — per sqft"],
    ["foundation", "foundation_pier_sqft",       12.00, "[Manual] pier-and-beam foundation — per sqft"],

    # --- Windows / Doors ---
    ["windows_doors", "window_builder",          325.00, "[Manual] builder-grade window — each"],
    ["windows_doors", "window_mid",              575.00, "[Manual] mid-range window — each"],
    ["windows_doors", "window_premium",          950.00, "[Manual] premium window — each"],
    ["windows_doors", "exterior_door_install",   850.00, "[Manual] exterior door install — each"],
    ["windows_doors", "interior_door_install",   225.00, "[Manual] interior door install — each"],

    # --- Insulation ---
    ["insulation", "insulation_batt_sqft",  1.35, "[Manual] batt insulation — per sqft"],
    ["insulation", "insulation_blown_sqft", 1.75, "[Manual] blown-in insulation — per sqft"],
    ["insulation", "insulation_spray_sqft", 3.25, "[Manual] spray foam insulation — per sqft"],

    # --- Permits / Engineering ---
    ["permits", "permit_base_fee",              450.00, "[Manual] base building permit fee"],
    ["permits", "structural_engineering_fee", 1800.00, "[Manual] structural engineering — each"],

    # --- Site Prep ---
    ["site_prep", "site_excavation_sqft", 4.50, "[Manual] excavation — per sqft"],
    ["site_prep", "site_clearing_sqft",   1.25, "[Manual] site clearing — per sqft"],
  ].freeze

  def up
    now = Time.current
    rows = ADDITION_CLUSTER_SEEDS.map do |trade, key, value, description|
      {
        trade:          trade,
        pricing_key:    key,
        description:    description,
        value:          value,
        last_synced_at: now,
        created_at:     now,
        updated_at:     now,
      }
    end
    DefaultPricing.upsert_all(rows, unique_by: [:trade, :pricing_key])
  end

  def down
    ADDITION_CLUSTER_SEEDS.each do |trade, key, _value, _desc|
      DefaultPricing.where(trade: trade, pricing_key: key).delete_all
    end
  end
end
