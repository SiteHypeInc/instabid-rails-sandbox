class MaterialListGenerator
  class UnsupportedTrade < StandardError; end

  # Ported from materialListGenerator.js (Node 411). Formulas and default
  # unit prices match the legacy implementation verbatim so results land in
  # the same ballpark as the trade breakdown spreadsheets. One trade at a
  # time — roofing first (TEA-230). Remaining trades follow in later PRs.
  def self.call(trade:, criteria:, contractor_id: nil, hourly_rate: 65)
    new(trade: trade, criteria: criteria, contractor_id: contractor_id, hourly_rate: hourly_rate).call
  end

  def initialize(trade:, criteria:, contractor_id:, hourly_rate:)
    @trade         = trade.to_s.downcase
    @criteria      = criteria.with_indifferent_access
    @contractor_id = contractor_id
    @hourly_rate   = hourly_rate
  end

  def call
    case @trade
    when "roofing" then build_roofing
    else
      raise UnsupportedTrade, "trade #{@trade.inspect} not yet ported"
    end
  end

  private

  def price(key, default)
    PricingResolver.price(trade: @trade, key: key, contractor_id: @contractor_id, default: default)
  end

  # -- Roofing -------------------------------------------------------------

  ROOFING_PITCH_MULTIPLIERS = {
    "3/12"   => 1.0,
    "4/12"   => 1.0,
    "5/12"   => 1.05,
    "6/12"   => 1.1,
    "7/12"   => 1.15,
    "8/12"   => 1.2,
    "9/12"   => 1.3,
    "10/12"  => 1.4,
    "11/12"  => 1.5,
    "12/12+" => 1.6
  }.freeze
  ROOFING_WASTE        = 1.10
  ROOFING_DEFAULT_PITCH_MULT = 1.1

  def build_roofing
    square_feet        = (@criteria[:squareFeet] || @criteria[:square_feet] || 2000).to_f
    layers             = (@criteria[:layers] || 1).to_i
    chimneys           = (@criteria[:chimneys] || 0).to_i
    skylights          = (@criteria[:skylights] || 0).to_i
    valleys            = (@criteria[:valleys] || 0).to_i
    plywood_sqft       = (@criteria[:plywoodSqft] || @criteria[:plywood_sqft] || 0).to_f
    existing_roof_type = (@criteria[:existingRoofType] || @criteria[:existing_roof_type] || "asphalt").to_s
    pitch              = (@criteria[:pitch] || "6/12").to_s
    ridge_vent_feet    = (@criteria[:ridgeVentFeet] || @criteria[:ridge_vent_feet] || 0).to_f
    material_type      = (@criteria[:material] || "").to_s.downcase

    pitch_mult = ROOFING_PITCH_MULTIPLIERS[pitch] || ROOFING_DEFAULT_PITCH_MULT
    perimeter    = Math.sqrt(square_feet) * 4
    ridge_length = Math.sqrt(square_feet) / 2

    material_list = []

    material_list << roofing_shingles_line(material_type, square_feet)

    underlayment_rolls = (square_feet / 400.0).ceil
    underlayment_unit  = price("underlayment_roll", 45.00)
    material_list << {
      item:       "Underlayment",
      quantity:   underlayment_rolls,
      unit:       "rolls",
      unit_cost:  underlayment_unit,
      total_cost: underlayment_rolls * underlayment_unit,
      category:   "underlayment"
    }

    nail_boxes = (square_feet / 1000.0).ceil
    nail_unit  = price("nails_box", 85.00)
    material_list << {
      item:       "Roofing Nails",
      quantity:   nail_boxes,
      unit:       "boxes",
      unit_cost:  nail_unit,
      total_cost: nail_boxes * nail_unit,
      category:   "fasteners"
    }

    starter_qty  = perimeter.ceil
    starter_unit = price("starter_lf", 2.50)
    material_list << {
      item:       "Starter Shingles",
      quantity:   starter_qty,
      unit:       "linear ft",
      unit_cost:  starter_unit,
      total_cost: starter_qty * starter_unit,
      category:   "shingles"
    }

    ridge_qty  = ridge_length.ceil
    ridge_unit = price("ridge_lf", 3.00)
    material_list << {
      item:       "Ridge Cap",
      quantity:   ridge_qty,
      unit:       "linear ft",
      unit_cost:  ridge_unit,
      total_cost: ridge_qty * ridge_unit,
      category:   "shingles"
    }

    drip_qty  = perimeter.ceil
    drip_unit = price("drip_edge_lf", 2.75)
    material_list << {
      item:       "Drip Edge",
      quantity:   drip_qty,
      unit:       "linear ft",
      unit_cost:  drip_unit,
      total_cost: drip_qty * drip_unit,
      category:   "flashing"
    }

    ice_water_lf   = (perimeter * 0.4).ceil
    ice_water_unit = price("ice_shield_lf", 4.50)
    material_list << {
      item:       "Ice & Water Shield",
      quantity:   ice_water_lf,
      unit:       "linear ft",
      unit_cost:  ice_water_unit,
      total_cost: ice_water_lf * ice_water_unit,
      category:   "underlayment"
    }

    vents_needed = (square_feet / 150.0).ceil
    vent_unit    = price("vent_unit", 25.00)
    material_list << {
      item:       "Roof Vents",
      quantity:   vents_needed,
      unit:       "vents",
      unit_cost:  vent_unit,
      total_cost: vents_needed * vent_unit,
      category:   "ventilation"
    }

    if ridge_vent_feet > 0
      rv_qty  = ridge_vent_feet.ceil
      rv_unit = price("ridge_vent_lf", 5.50)
      material_list << {
        item:       "Ridge Vent",
        quantity:   rv_qty,
        unit:       "linear ft",
        unit_cost:  rv_unit,
        total_cost: rv_qty * rv_unit,
        category:   "ventilation"
      }
    end

    if plywood_sqft > 0
      sheets_needed = ((plywood_sqft / 32.0) * ROOFING_WASTE).ceil
      osb_unit      = price("osb_sheet", 28.00)
      material_list << {
        item:       "OSB Sheathing",
        quantity:   sheets_needed,
        unit:       "sheets",
        unit_cost:  osb_unit,
        total_cost: sheets_needed * osb_unit,
        category:   "sheathing"
      }
    end

    disposal_rate = case existing_roof_type
                    when "wood_shake" then price("disposal_wood_sqft",    0.40)
                    when "metal"      then price("disposal_metal_sqft",   0.50)
                    when "tile"       then price("disposal_tile_sqft",    0.75)
                    else                    price("disposal_asphalt_sqft", 0.40)
                    end
    disposal_cost = square_feet * layers * disposal_rate
    material_list << {
      item:       "Disposal/Dumpster",
      quantity:   layers,
      unit:       "layer(s)",
      unit_cost:  square_feet * disposal_rate,
      total_cost: disposal_cost,
      category:   "disposal"
    }

    if chimneys > 0
      cf_unit = price("chimney_flash", 125.00)
      material_list << {
        item:       "Chimney Flashing Kit",
        quantity:   chimneys,
        unit:       "kits",
        unit_cost:  cf_unit,
        total_cost: chimneys * cf_unit,
        category:   "flashing"
      }
    end

    if skylights > 0
      sf_unit = price("skylight_flash", 85.00)
      material_list << {
        item:       "Skylight Flashing Kit",
        quantity:   skylights,
        unit:       "kits",
        unit_cost:  sf_unit,
        total_cost: skylights * sf_unit,
        category:   "flashing"
      }
    end

    if valleys > 0
      valley_lf   = valleys * 10
      valley_unit = price("valley_lf", 6.00)
      material_list << {
        item:       "Valley Flashing",
        quantity:   valley_lf,
        unit:       "linear ft",
        unit_cost:  valley_unit,
        total_cost: valley_lf * valley_unit,
        category:   "flashing"
      }
    end

    total_material_cost = material_list.reject { |i| i[:category] == "Labor" }
                                       .sum { |i| i[:total_cost] }

    labor_hours  = square_feet * 0.04
    labor_hours *= pitch_mult
    labor_hours += chimneys * 3
    labor_hours += skylights * 2
    labor_hours  = (labor_hours * 10).round / 10.0

    {
      trade:                  "roofing",
      total_material_cost:    total_material_cost,
      labor_hours:            labor_hours,
      material_list:          material_list,
      complexity_multiplier:  pitch_mult
    }
  end

  def roofing_shingles_line(material_type, square_feet)
    unit_price, calc_method, item_name =
      if material_type.include?("3-tab") || material_type.include?("asphalt")
        [price("mat_asphalt", 40.00), :bundle, "Architectural Shingles"]
      elsif material_type.include?("architectural")
        [price("mat_arch", 44.96), :bundle, "Architectural Shingles"]
      elsif material_type.include?("metal")
        [price("mat_metal", 9.50), :sqft, "Metal Roofing"]
      elsif material_type.include?("tile")
        [price("mat_tile", 12.00), :sqft, "Tile Roofing"]
      elsif material_type.include?("wood") || material_type.include?("shake")
        [price("mat_wood_shake", 14.00), :sqft, "Wood Shake"]
      else
        [price("mat_arch", 44.96), :bundle, "Architectural Shingles"]
      end

    if calc_method == :bundle
      squares  = square_feet / 100.0
      quantity = (squares * 3 * ROOFING_WASTE).ceil
      unit     = "bundles"
    else
      quantity = (square_feet * ROOFING_WASTE).ceil
      unit     = "sqft"
    end

    {
      item:       item_name,
      quantity:   quantity,
      unit:       unit,
      unit_cost:  unit_price,
      total_cost: quantity * unit_price,
      category:   "shingles"
    }
  end
end
