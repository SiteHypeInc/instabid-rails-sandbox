class SeedBathClusterPricingKeys < ActiveRecord::Migration[8.1]
  # TEA-240 Bath cluster seeds. All [Manual] defaults derived from TEA-238 spec
  # ranges and typical retail. HD Live / Web Search backfill tracked separately.

  BATH_CLUSTER_SEEDS = [
    # --- Vanity (grade × width grid) ---
    ["vanity", "vanity_stock_24",        350.00, "[Manual] 24in stock vanity"],
    ["vanity", "vanity_stock_30",        475.00, "[Manual] 30in stock vanity"],
    ["vanity", "vanity_stock_36",        625.00, "[Manual] 36in stock vanity"],
    ["vanity", "vanity_stock_48",        850.00, "[Manual] 48in stock vanity"],
    ["vanity", "vanity_stock_60",       1350.00, "[Manual] 60in stock double vanity"],
    ["vanity", "vanity_stock_72",       1650.00, "[Manual] 72in stock double vanity"],
    ["vanity", "vanity_semi_custom_30",  760.00, "[Manual] 30in semi-custom vanity"],
    ["vanity", "vanity_semi_custom_36", 1000.00, "[Manual] 36in semi-custom vanity"],
    ["vanity", "vanity_semi_custom_48", 1360.00, "[Manual] 48in semi-custom vanity"],
    ["vanity", "vanity_semi_custom_60", 2160.00, "[Manual] 60in semi-custom double vanity"],
    ["vanity", "vanity_custom_36",      1500.00, "[Manual] 36in custom vanity"],
    ["vanity", "vanity_custom_48",      2040.00, "[Manual] 48in custom vanity"],
    ["vanity", "vanity_custom_60",      3240.00, "[Manual] 60in custom double vanity"],
    ["vanity", "vanity_floating_36",    1125.00, "[Manual] 36in floating vanity"],
    ["vanity", "vanity_floating_48",    1530.00, "[Manual] 48in floating vanity"],
    ["vanity", "vanity_medicine_cab_surface",   185.00, "[Manual] surface-mount medicine cab"],
    ["vanity", "vanity_medicine_cab_recessed",  325.00, "[Manual] recessed medicine cab"],

    # --- Tile ---
    ["tile", "floor_tile_ceramic",    5.50,  "[Manual] ceramic tile — per sqft"],
    ["tile", "floor_tile_porcelain",  7.25,  "[Manual] porcelain tile — per sqft"],
    ["tile", "floor_marble",         12.00,  "[Manual] natural stone / marble — per sqft"],
    ["tile", "tile_thinset_bag",     17.74,  "[Manual] thinset bag — each (shared)"],
    ["tile", "tile_grout_bag",       12.00,  "[Manual] grout bag — each (shared)"],

    # --- Glass Enclosure ---
    ["glass", "glass_enclosure_framed",          950.00, "[Manual] framed glass enclosure"],
    ["glass", "glass_enclosure_semi_frameless", 1850.00, "[Manual] semi-frameless enclosure"],
    ["glass", "glass_enclosure_frameless",      3500.00, "[Manual] frameless enclosure"],

    # --- Shower System ---
    ["shower", "shower_system_single",   425.00, "[Manual] single-head shower system"],
    ["shower", "shower_system_rain",     850.00, "[Manual] rain + handheld shower system"],
    ["shower", "shower_system_multi",   2250.00, "[Manual] multi-head spa shower system"],
    ["shower", "shower_niche_each",      225.00, "[Manual] shower niche (each)"],

    # --- Waterproofing ---
    ["waterproofing", "waterproofing_sqft", 8.50, "[Manual] waterproofing membrane — per sqft"],

    # --- Heated Floor ---
    ["heated_floor", "heated_floor_mat_sqft",    14.00, "[Manual] electric heated floor mat — per sqft"],
    ["heated_floor", "heated_floor_thermostat", 185.00, "[Manual] programmable floor thermostat"],
  ].freeze

  def up
    now = Time.current
    rows = BATH_CLUSTER_SEEDS.map do |trade, key, value, description|
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
    BATH_CLUSTER_SEEDS.each do |trade, key, _value, _desc|
      DefaultPricing.where(trade: trade, pricing_key: key).delete_all
    end
  end
end
