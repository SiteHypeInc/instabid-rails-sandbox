class SeedKitchenClusterPricingKeys < ActiveRecord::Migration[8.1]
  # Seeds default_pricings for the TEA-240 Kitchen cluster builders.
  # Every row is tagged [Manual] in description because these are derived
  # from the TEA-238 spec's stated trade-total examples and typical retail
  # ranges — not from HD Live or Web Search. Backfill with sourced prices
  # lands in a follow-up ticket.

  KITCHEN_CLUSTER_SEEDS = [
    # --- Cabinets ---
    ["cabinets", "cab_base_30_stock",  200.00, "[Manual] stock base cab, 30in — per LF"],
    ["cabinets", "cab_base_30_semi",   350.00, "[Manual] semi-custom base cab, 30in — per LF"],
    ["cabinets", "cab_base_custom_lf", 600.00, "[Manual] full-custom base cab — per LF"],
    ["cabinets", "cab_wall_lf",        150.00, "[Manual] wall cabinet — per LF (stock)"],
    ["cabinets", "cab_tall_stock",     450.00, "[Manual] tall/pantry cab — each"],
    ["cabinets", "cab_hardware_pull",    3.50, "[Manual] basic cabinet pull/knob — each"],
    ["cabinets", "cab_hardware_knob",    3.50, "[Manual] basic cabinet knob — each"],
    ["cabinets", "cab_hinge_soft_close", 4.50, "[Manual] soft-close hinge — each"],
    ["cabinets", "cab_drawer_slide",    18.00, "[Manual] soft-close drawer slide pair — each"],
    ["cabinets", "cab_crown_lf",        12.00, "[Manual] cabinet crown molding — per LF"],
    ["cabinets", "cab_lazy_susan",     185.00, "[Manual] lazy susan insert — each"],
    ["cabinets", "cab_pullout_shelf",  125.00, "[Manual] pull-out shelf — each"],

    # --- Countertops ---
    ["countertops", "counter_laminate_sqft",       25.00, "[Manual] laminate — per sqft"],
    ["countertops", "counter_butcherblock_sqft",   45.00, "[Manual] butcher block — per sqft"],
    ["countertops", "counter_solidsurface_sqft",   55.00, "[Manual] solid surface — per sqft"],
    ["countertops", "counter_quartz_sqft",         75.00, "[Manual] quartz — per sqft"],
    ["countertops", "counter_granite_sqft",        65.00, "[Manual] granite — per sqft"],
    ["countertops", "counter_marble_sqft",        120.00, "[Manual] marble — per sqft"],
    ["countertops", "counter_edge_basic_lf",        8.00, "[Manual] basic edge profile — per LF"],
    ["countertops", "counter_edge_premium_lf",     18.00, "[Manual] premium edge (ogee/bevel) — per LF"],
    ["countertops", "counter_sink_cutout",        150.00, "[Manual] sink cutout — each"],
    ["countertops", "counter_cooktop_cutout",     175.00, "[Manual] cooktop cutout — each"],

    # --- Backsplash ---
    ["backsplash", "backsplash_subway_sqft",  9.00, "[Manual] subway tile — per sqft"],
    ["backsplash", "backsplash_mosaic_sqft", 22.00, "[Manual] mosaic tile — per sqft"],
    ["backsplash", "tile_thinset_bag",       17.74, "[Manual] thinset mortar bag — each"],
    ["backsplash", "tile_grout_bag",         12.00, "[Manual] grout bag — each"],

    # --- Appliances ---
    ["appliances", "appliance_builder",            3500.00, "[Manual] builder-grade package allowance"],
    ["appliances", "appliance_mid",                6500.00, "[Manual] mid-range package allowance"],
    ["appliances", "appliance_premium",           11000.00, "[Manual] premium package allowance"],
    ["appliances", "appliance_luxury",            20000.00, "[Manual] luxury package allowance"],
    ["appliances", "appliance_gas_line",            500.00, "[Manual] gas line to range — each"],
    ["appliances", "appliance_hood_roof_patch",     450.00, "[Manual] roof penetration patch for hood vent"],

    # --- Demolition ---
    ["demolition", "demo_per_sqft_kitchen",  4.50, "[Manual] kitchen demo — per sqft"],
    ["demolition", "demo_per_sqft_bathroom", 6.00, "[Manual] bathroom demo — per sqft"],
    ["demolition", "demo_per_sqft_bath",     6.00, "[Manual] bath demo — per sqft (alias)"],
    ["demolition", "demo_per_sqft_addition", 2.50, "[Manual] addition tie-in demo — per sqft"],
    ["demolition", "demo_per_sqft_whole",    5.00, "[Manual] whole-home demo — per sqft"],
    ["demolition", "demo_dumpster_10yd",   425.00, "[Manual] 10yd dumpster rental — each"],

    # --- Trim / Finish Carpentry ---
    ["trim", "trim_baseboard_lf",         2.75, "[Manual] baseboard trim — per LF"],
    ["trim", "crown_molding_lf",          6.50, "[Manual] crown molding — per LF"],
    ["trim", "trim_door_casing_set",     48.00, "[Manual] interior door casing set"],
    ["trim", "trim_window_casing_set",   42.00, "[Manual] window casing set"],
  ].freeze

  def up
    now = Time.current
    rows = KITCHEN_CLUSTER_SEEDS.map do |trade, key, value, description|
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
    keys = KITCHEN_CLUSTER_SEEDS.map { |row| row[1] }
    DefaultPricing.where(pricing_key: keys).delete_all
  end
end
