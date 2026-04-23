module Admin
  # Per-trade field definitions for the TEA-236 test estimate sandbox form.
  # These mirror the `build_<trade>` methods in MaterialListGenerator so the
  # sandbox form stays aligned with the customer-facing estimate flow. Update
  # here when a new field lands in the service.
  module TestEstimatesHelper
    PITCH_OPTIONS = %w[3/12 4/12 5/12 6/12 7/12 8/12 9/12 10/12 11/12 12/12+].freeze
    YES_NO        = %w[no yes].freeze

    TRADE_FIELDS = {
      "roofing" => [
        { name: "squareFeet",       label: "Square Feet",          type: :number, default: 2000, step: 1 },
        { name: "pitch",            label: "Pitch",                type: :select, options: PITCH_OPTIONS, default: "6/12" },
        { name: "material",         label: "Material",             type: :select, options: %w[asphalt architectural metal tile wood], default: "architectural" },
        { name: "layers",           label: "Existing Layers",      type: :number, default: 1, step: 1 },
        { name: "chimneys",         label: "Chimneys",             type: :number, default: 0, step: 1 },
        { name: "skylights",        label: "Skylights",            type: :number, default: 0, step: 1 },
        { name: "valleys",          label: "Valleys",              type: :number, default: 0, step: 1 },
        { name: "plywoodSqft",      label: "Plywood Sqft",         type: :number, default: 0, step: 1 },
        { name: "existingRoofType", label: "Existing Roof Type",   type: :select, options: %w[asphalt wood_shake metal tile], default: "asphalt" },
        { name: "ridgeVentFeet",    label: "Ridge Vent (LF)",      type: :number, default: 0, step: 1 }
      ],

      "plumbing" => [
        { name: "serviceType",         label: "Service Type",           type: :select, options: %w[general rough_in fixture_swap remodel], default: "general" },
        { name: "squareFeet",          label: "Square Feet",            type: :number, default: 2000, step: 1 },
        { name: "stories",             label: "Stories",                type: :number, default: 1, step: 1 },
        { name: "bathrooms",           label: "Bathrooms",              type: :number, default: 2, step: 1 },
        { name: "kitchens",            label: "Kitchens",               type: :number, default: 1, step: 1 },
        { name: "laundryRooms",        label: "Laundry Rooms",          type: :number, default: 0, step: 1 },
        { name: "accessType",          label: "Access Type",            type: :select, options: %w[basement crawlspace slab], default: "basement" },
        { name: "heaterType",          label: "Water Heater Type",      type: :select, options: %w[tank tankless hybrid], default: "tank" },
        { name: "waterHeaterLocation", label: "Water Heater Location",  type: :select, options: %w[garage basement closet attic], default: "garage" },
        { name: "gasLineNeeded",       label: "Gas Line Needed",        type: :select, options: YES_NO, default: "no" },
        { name: "mainLineReplacement", label: "Main Line Replacement",  type: :select, options: YES_NO, default: "no" },
        { name: "garbageDisposal",     label: "Garbage Disposal",       type: :select, options: YES_NO, default: "no" },
        { name: "iceMaker",            label: "Ice Maker Line",         type: :select, options: YES_NO, default: "no" },
        { name: "waterSoftener",       label: "Water Softener",         type: :select, options: YES_NO, default: "no" },
        { name: "dishwasherHookup",    label: "Dishwasher Hookup",      type: :select, options: YES_NO, default: "no" },
        { name: "toiletCount",         label: "Toilets",                type: :number, default: 0, step: 1 },
        { name: "sinkCount",           label: "Sinks",                  type: :number, default: 0, step: 1 },
        { name: "faucetCount",         label: "Faucets",                type: :number, default: 0, step: 1 },
        { name: "tubShowerCount",      label: "Tubs/Showers",           type: :number, default: 0, step: 1 }
      ],

      "drywall" => [
        { name: "squareFeet",    label: "Square Feet",    type: :number, default: 2000, step: 1 },
        { name: "projectType",   label: "Project Type",   type: :select, options: %w[new_construction remodel repair], default: "new_construction" },
        { name: "rooms",         label: "Rooms",          type: :number, default: 1, step: 1 },
        { name: "ceilingHeight", label: "Ceiling Height", type: :select, options: %w[8ft 9ft 10ft 12ft], default: "8ft" },
        { name: "finishLevel",   label: "Finish Level",   type: :select, options: %w[level_3_standard level_4_smooth level_5_premium], default: "level_3_standard" },
        { name: "textureType",   label: "Texture",        type: :select, options: %w[none orange_peel knockdown popcorn skip_trowel], default: "none" },
        { name: "damageExtent",  label: "Damage Extent",  type: :select, options: %w[minor moderate major], default: "minor" }
      ],

      "flooring" => [
        { name: "squareFeet",     label: "Square Feet",       type: :number, default: 1000, step: 1 },
        { name: "flooringType",   label: "Flooring Type",     type: :select, options: %w[carpet vinyl laminate lvp engineered_hardwood solid_hardwood ceramic_tile porcelain_tile], default: "lvp" },
        { name: "removal",        label: "Remove Existing",   type: :select, options: YES_NO, default: "no" },
        { name: "subfloorRepair", label: "Subfloor Repair",   type: :select, options: YES_NO, default: "no" },
        { name: "underlayment",   label: "Underlayment",      type: :select, options: %w[yes no], default: "yes" },
        { name: "baseboard",      label: "Baseboard (LF)",    type: :number, default: 0, step: 1 },
        { name: "complexity",     label: "Complexity",        type: :select, options: %w[simple standard complex], default: "standard" }
      ],

      "painting" => [
        { name: "squareFeet",          label: "Square Feet",        type: :number, default: 2000, step: 1 },
        { name: "paintType",           label: "Paint Type",         type: :select, options: %w[interior exterior both], default: "interior" },
        { name: "stories",             label: "Stories",            type: :number, default: 1, step: 1 },
        { name: "coats",               label: "Coats",              type: :number, default: 2, step: 1 },
        { name: "includeCeilings",     label: "Include Ceilings",   type: :select, options: YES_NO, default: "no" },
        { name: "trimLinearFeet",      label: "Trim (LF)",          type: :number, default: 0, step: 1 },
        { name: "doorCount",           label: "Doors",              type: :number, default: 0, step: 1 },
        { name: "windowCount",         label: "Windows",            type: :number, default: 0, step: 1 },
        { name: "sidingCondition",     label: "Siding Condition",   type: :select, options: %w[good fair poor], default: "good" },
        { name: "powerWashing",        label: "Power Washing",      type: :select, options: YES_NO, default: "no" },
        { name: "wallCondition",       label: "Wall Condition",     type: :select, options: %w[smooth textured damaged], default: "smooth" },
        { name: "patchingNeeded",      label: "Patching",           type: :select, options: %w[none minor moderate extensive], default: "none" },
        { name: "leadPaint",           label: "Lead Paint Abatement", type: :select, options: YES_NO, default: "no" },
        { name: "colorChangeDramatic", label: "Dramatic Color Change", type: :select, options: YES_NO, default: "no" }
      ],

      "siding" => [
        { name: "squareFeet",     label: "Square Feet",          type: :number, default: 1500, step: 1 },
        { name: "sidingType",     label: "Siding Type",          type: :select, options: %w[vinyl fiber_cement wood metal stucco wood_cedar metal_aluminum], default: "vinyl" },
        { name: "stories",        label: "Stories",              type: :number, default: 1, step: 1 },
        { name: "needsRemoval",   label: "Needs Removal",        type: :select, options: YES_NO, default: "no" },
        { name: "windowCount",    label: "Windows to Wrap",      type: :number, default: 0, step: 1 },
        { name: "doorCount",      label: "Doors to Wrap",        type: :number, default: 0, step: 1 },
        { name: "trimLinearFeet", label: "Trim (LF)",            type: :number, default: 0, step: 1 }
      ],

      "hvac" => [
        { name: "squareFeet",  label: "Square Feet", type: :number, default: 2000, step: 1 },
        { name: "systemType",  label: "System Type", type: :select, options: %w[furnace ac heatpump minisplit], default: "furnace" },
        { name: "efficiency",  label: "Efficiency",  type: :select, options: %w[standard high premium], default: "standard" },
        { name: "ductwork",    label: "Ductwork",    type: :select, options: %w[existing new repair], default: "existing" },
        { name: "stories",     label: "Stories",     type: :number, default: 1, step: 1 },
        { name: "zoneCount",   label: "Zones",       type: :number, default: 1, step: 1 },
        { name: "thermostats", label: "Thermostats", type: :number, default: 1, step: 1 }
      ],

      "electrical" => [
        { name: "squareFeet",      label: "Square Feet",        type: :number, default: 2000, step: 1 },
        { name: "serviceType",     label: "Service Type",       type: :select, options: %w[general circuits panel rewire], default: "general" },
        { name: "amperage",        label: "Panel Amperage",     type: :select, options: %w[100 200 400], default: "200" },
        { name: "homeAge",         label: "Home Age",           type: :select, options: ["pre-1960", "1960-1990", "1990+"], default: "1990+" },
        { name: "stories",         label: "Stories",            type: :number, default: 1, step: 1 },
        { name: "outletCount",     label: "Outlets",            type: :number, default: 0, step: 1 },
        { name: "gfciCount",       label: "GFCI Outlets",       type: :number, default: 0, step: 1 },
        { name: "switchCount",     label: "Switches",           type: :number, default: 0, step: 1 },
        { name: "dimmerCount",     label: "Dimmers",            type: :number, default: 0, step: 1 },
        { name: "fixtureCount",    label: "Light Fixtures",     type: :number, default: 0, step: 1 },
        { name: "recessedCount",   label: "Recessed Lights",    type: :number, default: 0, step: 1 },
        { name: "ceilingFanCount", label: "Ceiling Fans",       type: :number, default: 0, step: 1 },
        { name: "circuits20a",     label: "20A Circuits",       type: :number, default: 0, step: 1 },
        { name: "circuits30a",     label: "30A Circuits",       type: :number, default: 0, step: 1 },
        { name: "circuits50a",     label: "50A Circuits",       type: :number, default: 0, step: 1 },
        { name: "evCharger",       label: "EV Charger",         type: :select, options: YES_NO, default: "no" },
        { name: "permit",          label: "Pull Permit",        type: :select, options: YES_NO, default: "no" }
      ]
    }.freeze

    def trade_fields(trade)
      TRADE_FIELDS[trade.to_s] || []
    end

    def test_estimate_field_value(trade, field, posted_criteria)
      posted = posted_criteria[trade.to_s] || {}
      v = posted[field[:name].to_s]
      return v unless v.nil? || v == ""

      field[:default]
    end

    def format_money(n)
      "$#{format('%0.2f', n.to_f)}"
    end

    def format_hours(n)
      format("%0.2f", n.to_f)
    end

    # ===================== TEA-239 Remodel scope ======================
    # Spec: TEA-238. Three remodel types, each with preset-driven trade
    # activation and type-specific form sections. See activation matrix
    # and section tables in the spec before editing these constants.

    REMODEL_TYPES = %w[kitchen bathroom addition].freeze

    REMODEL_TYPE_LABELS = {
      "kitchen"  => "Kitchen Remodel",
      "bathroom" => "Bathroom Remodel",
      "addition" => "Home Addition"
    }.freeze

    REMODEL_PRESETS = {
      "kitchen" => [
        { value: "cosmetic",      label: "Cosmetic Refresh" },
        { value: "pull_replace",  label: "Pull-and-Replace" },
        { value: "full_gut",      label: "Full Gut Same Layout" },
        { value: "full_reconfig", label: "Full Reconfiguration" }
      ],
      "bathroom" => [
        { value: "cosmetic",    label: "Cosmetic Refresh" },
        { value: "standard",    label: "Standard Full Bath" },
        { value: "shower_gut",  label: "Shower-Focused Gut" },
        { value: "spa_premium", label: "Spa / Primary Premium" }
      ],
      "addition" => [
        { value: "shell_only",   label: "Shell Only" },
        { value: "builder",      label: "Builder Grade Finish" },
        { value: "standard",     label: "Standard Finished Room" },
        { value: "premium_wet",  label: "Premium / Wet-Room" }
      ]
    }.freeze

    # Logical remodel trade packages per preset. Order matters for output.
    # "maybe" items are omitted; test form shows only definitely-activated.
    REMODEL_ACTIVATION_MATRIX = {
      "kitchen" => {
        "cosmetic"      => %w[general_conditions painting cleanup],
        "pull_replace"  => %w[general_conditions demolition cabinets countertops backsplash flooring painting plumbing_finish electrical_finish appliances trim cleanup],
        "full_gut"      => %w[general_conditions demolition drywall cabinets countertops backsplash flooring painting plumbing_finish electrical_rough electrical_finish hvac appliances trim cleanup],
        "full_reconfig" => %w[general_conditions demolition engineering framing drywall cabinets countertops backsplash flooring painting plumbing_rough plumbing_finish electrical_rough electrical_finish hvac appliances trim cleanup]
      },
      "bathroom" => {
        "cosmetic"    => %w[general_conditions accessories painting cleanup],
        "standard"    => %w[general_conditions demolition waterproofing drywall vanity countertop_bath tile toilet_fixtures accessories painting plumbing_finish electrical ventilation cleanup],
        "shower_gut"  => %w[general_conditions demolition framing waterproofing drywall vanity countertop_bath shower_system glass_enclosure tile toilet_fixtures accessories painting plumbing_rough plumbing_finish electrical ventilation cleanup],
        "spa_premium" => %w[general_conditions demolition framing waterproofing drywall vanity countertop_bath shower_system glass_enclosure tile toilet_fixtures accessories painting plumbing_rough plumbing_finish electrical ventilation heated_floor cleanup]
      },
      "addition" => {
        "shell_only"  => %w[site_prep engineering foundation framing roofing siding windows_doors insulation drywall cleanup],
        "builder"     => %w[site_prep engineering foundation framing roofing siding windows_doors insulation drywall interior_trim flooring painting electrical hvac cleanup],
        "standard"    => %w[site_prep engineering foundation framing roofing siding windows_doors insulation drywall interior_trim flooring painting electrical hvac cleanup],
        "premium_wet" => %w[site_prep engineering foundation framing roofing siding windows_doors insulation drywall interior_trim flooring painting electrical hvac plumbing_rough plumbing_finish tile fixtures_wet cleanup]
      }
    }.freeze

    # Map a logical remodel trade package to the MaterialListGenerator trade
    # that can actually build a material list for it. `nil` means the builder
    # isn't ported yet — the test form will render a [Builder not ported] row
    # and the gap gets flagged in the escalation comment.
    REMODEL_PACKAGE_TO_TRADE = {
      "general_conditions" => nil,
      "demolition"         => nil,
      "engineering"        => nil,
      "framing"            => nil,
      "foundation"         => nil,
      "site_prep"          => nil,
      "roofing"            => "roofing",
      "siding"             => "siding",
      "windows_doors"      => nil,
      "insulation"         => nil,
      "drywall"            => "drywall",
      "cabinets"           => nil,
      "countertops"        => nil,
      "countertop_bath"    => nil,
      "backsplash"         => nil,
      "tile"               => nil,
      "flooring"           => "flooring",
      "painting"           => "painting",
      "plumbing_rough"     => "plumbing",
      "plumbing_finish"    => "plumbing",
      "electrical_rough"   => "electrical",
      "electrical_finish"  => "electrical",
      "electrical"         => "electrical",
      "hvac"               => "hvac",
      "ventilation"        => "hvac",
      "appliances"         => nil,
      "trim"               => nil,
      "interior_trim"      => nil,
      "vanity"             => nil,
      "shower_system"      => nil,
      "glass_enclosure"    => nil,
      "toilet_fixtures"    => nil,
      "fixtures_wet"       => nil,
      "waterproofing"      => nil,
      "accessories"        => nil,
      "heated_floor"       => nil,
      "cleanup"            => nil
    }.freeze

    REMODEL_PACKAGE_LABELS = {
      "general_conditions" => "General Conditions",
      "demolition"         => "Demolition",
      "engineering"        => "Engineering / Permits",
      "framing"            => "Framing / Structural",
      "foundation"         => "Foundation",
      "site_prep"          => "Site Prep",
      "roofing"            => "Roofing",
      "siding"             => "Siding / Exterior",
      "windows_doors"      => "Windows / Doors",
      "insulation"         => "Insulation",
      "drywall"            => "Drywall",
      "cabinets"           => "Cabinets",
      "countertops"        => "Countertops",
      "countertop_bath"    => "Vanity Countertop",
      "backsplash"         => "Backsplash",
      "tile"               => "Tile",
      "flooring"           => "Flooring",
      "painting"           => "Painting",
      "plumbing_rough"     => "Plumbing Rough",
      "plumbing_finish"    => "Plumbing Finish",
      "electrical_rough"   => "Electrical Rough",
      "electrical_finish"  => "Electrical Finish",
      "electrical"         => "Electrical",
      "hvac"               => "HVAC",
      "ventilation"        => "Ventilation",
      "appliances"         => "Appliances",
      "trim"               => "Trim / Finish Carpentry",
      "interior_trim"      => "Interior Doors / Trim",
      "vanity"             => "Vanity / Cabinetry",
      "shower_system"      => "Shower System",
      "glass_enclosure"    => "Glass Enclosure",
      "toilet_fixtures"    => "Toilet / Fixtures",
      "fixtures_wet"       => "Fixtures (Wet Room)",
      "waterproofing"      => "Waterproofing",
      "accessories"        => "Accessories / Mirrors",
      "heated_floor"       => "Heated Floor",
      "cleanup"            => "Cleanup"
    }.freeze

    # Form sections per remodel type. Each section = [label, [fields...]].
    # Fields share the same {name,label,type,options,default,step} shape
    # as TRADE_FIELDS so the same rendering loop handles both modes.
    STATES_50 = %w[AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY].freeze
    YES_NO_BOOL = YES_NO

    PROJECT_BASICS = [
      { name: "customer_name",  label: "Customer Name",    type: :text,   default: "" },
      { name: "customer_email", label: "Customer Email",   type: :text,   default: "" },
      { name: "customer_phone", label: "Customer Phone",   type: :text,   default: "" },
      { name: "address",        label: "Property Address", type: :text,   default: "" },
      { name: "city",           label: "City",             type: :text,   default: "Denver" },
      { name: "state",          label: "State",            type: :select, options: STATES_50, default: "CO" },
      { name: "zip",            label: "ZIP",              type: :text,   default: "80202" }
    ].freeze

    REMODEL_SECTIONS = {
      "kitchen" => [
        { key: "basics", label: "Project Basics", fields: PROJECT_BASICS },
        { key: "scope",  label: "Kitchen Scope", fields: [
          { name: "kitchen_sqft",     label: "Kitchen Square Footage", type: :number, default: 180, step: 1 },
          { name: "layout_change",    label: "Layout Change",          type: :select, options: %w[none minor major], default: "none" },
          { name: "structural_work",  label: "Structural Work",        type: :select, options: %w[none non_load_bearing load_bearing_beam], default: "none" },
          { name: "occupied",         label: "Occupied During Work",   type: :select, options: YES_NO_BOOL, default: "no" }
        ]},
        { key: "cabinets", label: "Cabinets", fields: [
          { name: "cabinet_grade",     label: "Cabinet Grade",         type: :select, options: %w[stock semi_custom custom], default: "semi_custom" },
          { name: "base_cabinet_lf",   label: "Base Cabinet LF",       type: :number, default: 18, step: 1 },
          { name: "wall_cabinet_lf",   label: "Wall Cabinet LF",       type: :number, default: 14, step: 1 },
          { name: "tall_cabinets",     label: "Tall/Pantry Cabinets",  type: :number, default: 1, step: 1 },
          { name: "island",            label: "Island",                type: :select, options: %w[none standard large], default: "none" },
          { name: "hardware_grade",    label: "Cabinet Hardware",      type: :select, options: %w[basic mid premium], default: "mid" },
          { name: "soft_close_hinges", label: "Soft-Close Hinges",     type: :select, options: YES_NO_BOOL, default: "yes" },
          { name: "soft_close_slides", label: "Soft-Close Slides",     type: :select, options: YES_NO_BOOL, default: "yes" },
          { name: "crown_molding",     label: "Crown Molding",         type: :select, options: YES_NO_BOOL, default: "no" }
        ]},
        { key: "countertops", label: "Countertops", fields: [
          { name: "counter_material", label: "Countertop Material", type: :select, options: %w[laminate butcher_block solid_surface quartz granite marble], default: "quartz" },
          { name: "counter_sqft",     label: "Countertop Sqft",     type: :number, default: 40, step: 1, auto: "counter_sqft" },
          { name: "counter_edge",     label: "Edge Profile",        type: :select, options: %w[standard ogee beveled waterfall], default: "standard" },
          { name: "cooktop_cutout",   label: "Cooktop Cutout",      type: :select, options: YES_NO_BOOL, default: "no" }
        ]},
        { key: "backsplash", label: "Backsplash", fields: [
          { name: "backsplash_type", label: "Backsplash Type", type: :select, options: %w[none subway mosaic full_height match_counter], default: "subway" },
          { name: "backsplash_sqft", label: "Backsplash Sqft", type: :number, default: 27, step: 1, auto: "backsplash_sqft" }
        ]},
        { key: "appliances", label: "Appliances", fields: [
          { name: "appliance_pkg", label: "Appliance Package", type: :select, options: %w[reuse builder mid premium luxury], default: "mid" },
          { name: "range_type",    label: "Range Type",        type: :select, options: %w[electric gas induction], default: "gas" },
          { name: "ventilation",   label: "Ventilation",       type: :select, options: %w[recirculating wall_vented roof_vented], default: "wall_vented" }
        ]},
        { key: "flooring", label: "Flooring", fields: [
          { name: "flooring_material", label: "Flooring Material", type: :select, options: %w[keep lvp tile hardwood laminate], default: "lvp" },
          { name: "flooring_sqft",     label: "Flooring Sqft",     type: :number, default: 180, step: 1, auto: "flooring_sqft" },
          { name: "floor_removal",     label: "Floor Removal",     type: :select, options: YES_NO_BOOL, default: "yes" },
          { name: "subfloor_repair",   label: "Subfloor Repair",   type: :select, options: %w[none minor full], default: "none" }
        ]},
        { key: "plumbing", label: "Plumbing", fields: [
          { name: "sink_relocation",   label: "Sink Relocation",   type: :select, options: YES_NO_BOOL, default: "no" },
          { name: "sink_type",         label: "Sink Type",         type: :select, options: %w[single_bowl double_bowl farmhouse], default: "double_bowl" },
          { name: "faucet_grade",      label: "Faucet Grade",      type: :select, options: %w[basic mid premium], default: "mid" },
          { name: "dishwasher_hookup", label: "Dishwasher Hookup", type: :select, options: YES_NO_BOOL, default: "yes" },
          { name: "garbage_disposal",  label: "Garbage Disposal",  type: :select, options: YES_NO_BOOL, default: "yes" },
          { name: "pot_filler",        label: "Pot Filler",        type: :select, options: YES_NO_BOOL, default: "no" },
          { name: "ice_maker_line",    label: "Ice Maker Line",    type: :select, options: YES_NO_BOOL, default: "yes" }
        ]},
        { key: "electrical", label: "Electrical", fields: [
          { name: "recessed_lights",   label: "Recessed Lights",  type: :number, default: 6, step: 1 },
          { name: "pendant_lights",    label: "Pendant Lights",   type: :number, default: 3, step: 1 },
          { name: "under_cabinet",     label: "Under-Cabinet LED",type: :select, options: YES_NO_BOOL, default: "yes" },
          { name: "gfci_outlets",      label: "GFCI Outlets",     type: :number, default: 4, step: 1, auto: "gfci_count" },
          { name: "panel_upgrade",     label: "Panel Upgrade",    type: :select, options: %w[none sub_100 main_200], default: "none" }
        ]},
        { key: "painting", label: "Painting & Finishes", fields: [
          { name: "ceiling_paint", label: "Ceiling Painting", type: :select, options: YES_NO_BOOL, default: "yes" },
          { name: "trim_scope",    label: "Trim",             type: :select, options: %w[keep baseboard all_trim], default: "baseboard" }
        ]},
        { key: "hvac", label: "HVAC", fields: [
          { name: "hvac_changes", label: "HVAC Changes", type: :select, options: %w[none register_relocate duct_mod full_reroute], default: "none" }
        ]},
        { key: "addition_subset", label: "Addition (reconfig only)", preset_gate: %w[full_reconfig], fields: [
          { name: "addition_sqft",    label: "Addition Sqft",        type: :number, default: 0, step: 1 },
          { name: "foundation_type",  label: "Foundation Type",      type: :select, options: %w[slab crawlspace pier_beam], default: "slab" },
          { name: "new_windows",      label: "New Windows",          type: :number, default: 0, step: 1 },
          { name: "roof_tie_in",      label: "Roof Tie-In",          type: :select, options: %w[simple_shed gable hip complex_valley], default: "gable" }
        ]}
      ],

      "bathroom" => [
        { key: "basics", label: "Project Basics", fields: PROJECT_BASICS },
        { key: "scope", label: "Bathroom Scope", fields: [
          { name: "bathroom_type",  label: "Bathroom Type",  type: :select, options: %w[powder hall guest primary], default: "primary" },
          { name: "bathroom_sqft",  label: "Bathroom Sqft",  type: :number, default: 80, step: 1 },
          { name: "layout_change",  label: "Layout Change",  type: :select, options: %w[none vanity_moves full_reconfig], default: "none" },
          { name: "occupied",       label: "Occupied During Work", type: :select, options: YES_NO_BOOL, default: "no" }
        ]},
        { key: "bathing", label: "Bathing Fixtures", fields: [
          { name: "bathing_type",  label: "Bathing Type",  type: :select, options: %w[keep tub_shower walk_in_shower free_tub_sep_shower wet_room], default: "walk_in_shower" },
          { name: "shower_size",   label: "Shower Size",   type: :select, options: %w[36x36 48x36 60x36 custom], default: "48x36" },
          { name: "shower_glass",  label: "Shower Glass",  type: :select, options: %w[none framed semi_frameless frameless], default: "semi_frameless" },
          { name: "shower_system", label: "Shower System", type: :select, options: %w[single rain_handheld multi_spa], default: "single" },
          { name: "shower_niche",  label: "Shower Niche",  type: :select, options: %w[none single double triple], default: "single" },
          { name: "tub_type",      label: "Tub Type",      type: :select, options: %w[none alcove freestanding drop_in soaking], default: "none" }
        ]},
        { key: "vanity", label: "Vanity & Countertop", fields: [
          { name: "vanity_type",        label: "Vanity Type",         type: :select, options: %w[stock semi_custom custom floating], default: "semi_custom" },
          { name: "vanity_width",       label: "Vanity Width",        type: :select, options: %w[24 30 36 48 60 72], default: "48" },
          { name: "counter_material",   label: "Countertop Material", type: :select, options: %w[laminate solid_surface quartz granite marble], default: "quartz" },
          { name: "medicine_cabinet",   label: "Medicine Cabinet",    type: :select, options: %w[none surface recessed], default: "recessed" }
        ]},
        { key: "tile", label: "Tile", fields: [
          { name: "floor_tile_material", label: "Floor Tile Material", type: :select, options: %w[ceramic porcelain stone lvp], default: "porcelain" },
          { name: "floor_tile_sqft",     label: "Floor Tile Sqft",     type: :number, default: 80, step: 1, auto: "bath_sqft" },
          { name: "shower_wall_tile",    label: "Shower Wall Tile",    type: :select, options: %w[none partial_48 full_height floor_to_ceiling], default: "full_height" },
          { name: "tile_complexity",     label: "Tile Complexity",     type: :select, options: %w[standard subway_offset herringbone mosaic_accent], default: "standard" },
          { name: "accent_tile",         label: "Accent/Feature Wall", type: :select, options: YES_NO_BOOL, default: "no" }
        ]},
        { key: "toilet_fix", label: "Toilet & Fixtures", fields: [
          { name: "toilet_type",   label: "Toilet",       type: :select, options: %w[keep standard comfort wall_hung smart], default: "comfort" },
          { name: "faucet_grade",  label: "Faucet Grade", type: :select, options: %w[basic mid premium], default: "mid" }
        ]},
        { key: "systems", label: "Systems", fields: [
          { name: "heated_floor",    label: "Heated Floor",   type: :select, options: YES_NO_BOOL, default: "no" },
          { name: "exhaust_fan",     label: "Exhaust Fan",    type: :select, options: %w[keep standard humidity_sensing], default: "humidity_sensing" },
          { name: "vanity_lighting", label: "Vanity Lighting",type: :number, default: 2, step: 1 },
          { name: "recessed_lights", label: "Recessed Lights",type: :number, default: 2, step: 1 },
          { name: "gfci_outlets",    label: "GFCI Outlets",   type: :number, default: 1, step: 1, auto: "gfci_bath" }
        ]},
        { key: "painting", label: "Painting & Finishes", fields: [
          { name: "ceiling_paint", label: "Ceiling Painting", type: :select, options: YES_NO_BOOL, default: "yes" },
          { name: "trim_scope",    label: "Trim",             type: :select, options: %w[keep replace], default: "replace" }
        ]}
      ],

      "addition" => [
        { key: "basics", label: "Project Basics", fields: PROJECT_BASICS },
        { key: "scope", label: "Addition Scope", fields: [
          { name: "room_type",      label: "Room Type",        type: :select, options: %w[bedroom office family_room bath_addition primary_suite laundry_mudroom], default: "family_room" },
          { name: "addition_sqft",  label: "Addition Sqft",    type: :number, default: 400, step: 1 },
          { name: "stories",        label: "Stories",          type: :select, options: %w[one two], default: "one" }
        ]},
        { key: "shell", label: "Shell", fields: [
          { name: "foundation_type", label: "Foundation Type", type: :select, options: %w[slab crawlspace pier_beam basement_tie], default: "slab" },
          { name: "roof_tie_in",     label: "Roof Tie-In",     type: :select, options: %w[simple_shed gable hip complex_valley], default: "gable" },
          { name: "exterior_finish", label: "Exterior Finish", type: :select, options: %w[vinyl fiber_cement wood stucco], default: "fiber_cement" },
          { name: "windows",         label: "Windows",         type: :number, default: 3, step: 1 },
          { name: "exterior_doors",  label: "Exterior Doors",  type: :number, default: 1, step: 1 },
          { name: "window_grade",    label: "Window Grade",    type: :select, options: %w[builder mid premium], default: "mid" }
        ]},
        { key: "interior", label: "Interior Finishes", fields: [
          { name: "flooring_material", label: "Flooring Material", type: :select, options: %w[carpet lvp hardwood tile laminate], default: "lvp" },
          { name: "interior_doors",    label: "Interior Doors",    type: :number, default: 2, step: 1 },
          { name: "trim_level",        label: "Trim Level",        type: :select, options: %w[basic standard premium], default: "standard" },
          { name: "paint_level",       label: "Paint Level",       type: :select, options: %w[builder standard premium], default: "standard" },
          { name: "ceiling_height",    label: "Ceiling Height",    type: :select, options: %w[8ft 9ft 10ft vaulted], default: "9ft" }
        ]},
        { key: "systems", label: "Systems", fields: [
          { name: "hvac_scope",        label: "HVAC",            type: :select, options: %w[extend mini_split none], default: "extend" },
          { name: "recessed_lights",   label: "Recessed Lights", type: :number, default: 6, step: 1 },
          { name: "ceiling_fan",       label: "Ceiling Fan",     type: :select, options: YES_NO_BOOL, default: "yes" },
          { name: "insulation_type",   label: "Insulation",      type: :select, options: %w[batt spray_foam], default: "batt" }
        ]},
        { key: "wet_room", label: "Wet Room (if bath/suite/laundry)", preset_gate: %w[premium_wet], fields: [
          { name: "wet_room_type", label: "Wet Room Type", type: :select, options: %w[full_bath half_bath kitchenette laundry], default: "full_bath" }
        ]}
      ]
    }.freeze

    def remodel_types
      REMODEL_TYPES
    end

    def remodel_presets(type)
      REMODEL_PRESETS[type.to_s] || []
    end

    def remodel_sections(type)
      REMODEL_SECTIONS[type.to_s] || []
    end

    def remodel_type_label(type)
      REMODEL_TYPE_LABELS[type.to_s] || type.to_s.capitalize
    end

    def remodel_section_visible?(section, preset)
      gate = section[:preset_gate]
      gate.nil? || gate.include?(preset.to_s)
    end

    def remodel_field_value(type, section_key, field, posted_criteria)
      posted = (posted_criteria[type.to_s] || {})[section_key.to_s] || {}
      v = posted[field[:name].to_s]
      return v unless v.nil? || v == ""

      # Auto-calculated defaults fall through to spec-driven prefill based on
      # sibling fields. The user can always override.
      auto_default(type, field, posted_criteria) || field[:default]
    end

    # Spec "IMPLEMENTATION NOTES FOR TODD" — pre-filled defaults the user can
    # override. Pulls from sibling form values when present.
    def auto_default(type, field, posted)
      auto = field[:auto]
      return nil unless auto

      k = posted.dig(type.to_s, "cabinets") || {}
      case auto
      when "counter_sqft"
        base_lf = (k["base_cabinet_lf"] || 18).to_f
        (base_lf * 2).to_i
      when "backsplash_sqft"
        counter_sqft = ((posted.dig(type.to_s, "countertops") || {})["counter_sqft"] || 40).to_f
        # spec: "counter LF × 1.5" — approximated from sqft / 2 back to LF, × 1.5
        counter_lf = counter_sqft / 2.0
        (counter_lf * 1.5).to_i
      when "flooring_sqft"
        (posted.dig(type.to_s, "scope") || {})["kitchen_sqft"] || field[:default]
      when "gfci_count"
        kitchen_sqft = ((posted.dig(type.to_s, "scope") || {})["kitchen_sqft"] || 180).to_f
        [2, (kitchen_sqft / 45.0).ceil].max
      when "bath_sqft"
        (posted.dig(type.to_s, "scope") || {})["bathroom_sqft"] || field[:default]
      when "gfci_bath"
        1
      else
        field[:default]
      end
    end

    def remodel_packages_for(type, preset)
      (REMODEL_ACTIVATION_MATRIX[type.to_s] || {})[preset.to_s] || []
    end

    def remodel_package_label(pkg)
      REMODEL_PACKAGE_LABELS[pkg.to_s] || pkg.to_s.tr("_", " ").capitalize
    end

    # [HD Live] / [Web Search] / [Manual] label for a material list line.
    # PricingResolver is stub-only in the sandbox, so every line resolves from
    # the caller-supplied default → tag as [Manual]. When the resolver gets
    # DB-backed, update this to read the line's actual source.
    def price_source_label(_line)
      "[Manual]"
    end
  end
end
