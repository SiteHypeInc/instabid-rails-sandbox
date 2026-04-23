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
  end
end
