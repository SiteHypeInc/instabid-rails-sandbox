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
    when "roofing"  then build_roofing
    when "plumbing" then build_plumbing
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

  # -- Plumbing ------------------------------------------------------------

  PLUMBING_ACCESS_MULTIPLIERS = {
    "basement"   => 1.0,
    "crawlspace" => 1.15,
    "slab"       => 1.35
  }.freeze

  PLUMBING_LOCATION_MULTIPLIERS = {
    "garage"   => 1.0,
    "basement" => 1.0,
    "closet"   => 1.1,
    "attic"    => 1.25
  }.freeze

  def build_plumbing
    service_type          = (@criteria[:serviceType]          || @criteria[:service_type]          || "general").to_s
    square_feet           = (@criteria[:squareFeet]           || @criteria[:square_feet]           || 0).to_f
    stories               = (@criteria[:stories]              || 1).to_i
    bathrooms             = (@criteria[:bathrooms]            || 1).to_i
    kitchens              = (@criteria[:kitchens]             || 1).to_i
    laundry_rooms         = (@criteria[:laundryRooms]         || @criteria[:laundry_rooms]         || 0).to_i
    access_type           = (@criteria[:accessType]           || @criteria[:access_type]           || "basement").to_s
    heater_type           = (@criteria[:heaterType]           || @criteria[:heater_type]           || "tank").to_s
    water_heater_location = (@criteria[:waterHeaterLocation]  || @criteria[:water_heater_location] || "garage").to_s
    gas_line_needed       = (@criteria[:gasLineNeeded]        || @criteria[:gas_line_needed]       || "no").to_s
    main_line_replacement = (@criteria[:mainLineReplacement]  || @criteria[:main_line_replacement] || "no").to_s
    garbage_disposal      = (@criteria[:garbageDisposal]      || @criteria[:garbage_disposal]      || "no").to_s
    ice_maker             = (@criteria[:iceMaker]             || @criteria[:ice_maker]             || "no").to_s
    water_softener        = (@criteria[:waterSoftener]        || @criteria[:water_softener]        || "no").to_s
    dishwasher_hookup     = (@criteria[:dishwasherHookup]     || @criteria[:dishwasher_hookup]     || "no").to_s
    toilet_count          = (@criteria[:toiletCount]          || @criteria[:toilet_count]          || 0).to_i
    sink_count            = (@criteria[:sinkCount]            || @criteria[:sink_count]            || 0).to_i
    faucet_count          = (@criteria[:faucetCount]          || @criteria[:faucet_count]          || 0).to_i
    tub_shower_count      = (@criteria[:tubShowerCount]       || @criteria[:tub_shower_count]      || 0).to_i

    access_mult   = PLUMBING_ACCESS_MULTIPLIERS[access_type]             || 1.0
    location_mult = PLUMBING_LOCATION_MULTIPLIERS[water_heater_location] || 1.0

    material_list = []
    labor_hours   = 0.0

    case service_type
    when "repipe"
      if square_feet > 0
        base_pipe_feet    = square_feet * 0.5
        fixture_pipe_feet = (bathrooms * 25) + (kitchens * 30) + (laundry_rooms * 15)
        total_pipe_feet   = (base_pipe_feet + fixture_pipe_feet).ceil
        pex_unit          = price("pex_pipe_lf", 2.50)

        material_list << {
          item:       "PEX Pipe",
          quantity:   total_pipe_feet,
          unit:       "linear feet",
          unit_cost:  pex_unit,
          total_cost: total_pipe_feet * pex_unit,
          category:   "Pipe"
        }

        fittings_cost = total_pipe_feet * pex_unit * 0.30
        material_list << {
          item:       "Fittings & Connectors",
          quantity:   1,
          unit:       "set",
          unit_cost:  fittings_cost,
          total_cost: fittings_cost,
          category:   "Pipe"
        }

        valve_count = (bathrooms * 2) + (kitchens * 2) + laundry_rooms
        valve_unit  = price("shutoff_valve", 25.00)
        material_list << {
          item:       "Shutoff Valves",
          quantity:   valve_count,
          unit:       "valves",
          unit_cost:  valve_unit,
          total_cost: valve_count * valve_unit,
          category:   "Pipe"
        }

        labor_hours  = (square_feet / 100.0) * 5
        labor_hours *= 1.2  if stories >= 2
        labor_hours *= 1.15 if stories >= 3
        labor_hours *= access_mult

        if main_line_replacement == "yes"
          main_unit = price("main_line_replacement", 1200.00)
          material_list << {
            item:       "Main Line Replacement",
            quantity:   1,
            unit:       "job",
            unit_cost:  main_unit,
            total_cost: main_unit,
            category:   "Main Line"
          }
          labor_hours += 8
        end
      end

    when "water_heater"
      if heater_type == "tankless"
        if gas_line_needed == "yes"
          heater_unit = price("water_heater_tankless_gas",      3500.00)
          heater_name = "Tankless Water Heater (Gas)"
          labor_hours = 10
        else
          heater_unit = price("water_heater_tankless_electric", 2200.00)
          heater_name = "Tankless Water Heater (Electric)"
          labor_hours = 8
        end
      else
        heater_unit = price("water_heater_tank_50gal",          1600.00)
        heater_name = "Tank Water Heater (50 gal)"
        labor_hours = 6
      end

      material_list << {
        item:       heater_name,
        quantity:   1,
        unit:       "unit",
        unit_cost:  heater_unit,
        total_cost: heater_unit,
        category:   "Water Heater"
      }

      supplies_unit = price("water_heater_install_supplies", 150.00)
      material_list << {
        item:       "Installation Supplies (flex lines, fittings)",
        quantity:   1,
        unit:       "set",
        unit_cost:  supplies_unit,
        total_cost: supplies_unit,
        category:   "Water Heater"
      }

      labor_hours *= location_mult

      if gas_line_needed == "yes"
        gas_unit = price("gas_line_install", 500.00)
        material_list << {
          item:       "Gas Line Installation",
          quantity:   1,
          unit:       "job",
          unit_cost:  gas_unit,
          total_cost: gas_unit,
          category:   "Gas"
        }
        labor_hours += 4
      end

    when "fixture"
      if toilet_count > 0
        toilet_unit = price("fixture_toilet", 375.00)
        material_list << {
          item:       "Toilet Installation",
          quantity:   toilet_count,
          unit:       "fixtures",
          unit_cost:  toilet_unit,
          total_cost: toilet_unit * toilet_count,
          category:   "Fixtures"
        }
        labor_hours += 2.5 * toilet_count
      end

      if sink_count > 0
        sink_unit = price("fixture_sink", 450.00)
        material_list << {
          item:       "Sink Installation",
          quantity:   sink_count,
          unit:       "fixtures",
          unit_cost:  sink_unit,
          total_cost: sink_unit * sink_count,
          category:   "Fixtures"
        }
        labor_hours += 3 * sink_count
      end

      if faucet_count > 0
        faucet_unit = price("fixture_faucet", 262.00)
        material_list << {
          item:       "Faucet Installation",
          quantity:   faucet_count,
          unit:       "fixtures",
          unit_cost:  faucet_unit,
          total_cost: faucet_unit * faucet_count,
          category:   "Fixtures"
        }
        labor_hours += 1.5 * faucet_count
      end

      if tub_shower_count > 0
        tub_unit = price("fixture_tub_shower", 1200.00)
        material_list << {
          item:       "Tub/Shower Installation",
          quantity:   tub_shower_count,
          unit:       "fixtures",
          unit_cost:  tub_unit,
          total_cost: tub_unit * tub_shower_count,
          category:   "Fixtures"
        }
        labor_hours += 6 * tub_shower_count
      end

      if garbage_disposal == "yes"
        material_list << plumbing_garbage_disposal_line
        labor_hours += 1.5
      end
      if ice_maker == "yes"
        material_list << plumbing_ice_maker_line
        labor_hours += 1
      end
      if dishwasher_hookup == "yes"
        dw_unit = price("dishwasher_hookup", 200.00)
        material_list << {
          item:       "Dishwasher Hookup",
          quantity:   1,
          unit:       "hookup",
          unit_cost:  dw_unit,
          total_cost: dw_unit,
          category:   "Add-ons"
        }
        labor_hours += 2
      end

      labor_hours *= access_mult
      labor_hours  = [labor_hours, 2].max

    else # general
      service_unit = price("service_call", 95.00)
      material_list << {
        item:       "Service Call",
        quantity:   1,
        unit:       "visit",
        unit_cost:  service_unit,
        total_cost: service_unit,
        category:   "Service"
      }
      labor_hours = 2.0

      if garbage_disposal == "yes"
        material_list << plumbing_garbage_disposal_line
        labor_hours += 1.5
      end
      if ice_maker == "yes"
        material_list << plumbing_ice_maker_line
        labor_hours += 1
      end
      if water_softener == "yes"
        softener_unit = price("water_softener", 1800.00)
        material_list << {
          item:       "Water Softener Installation",
          quantity:   1,
          unit:       "unit",
          unit_cost:  softener_unit,
          total_cost: softener_unit,
          category:   "Add-ons"
        }
        labor_hours += 4
      end
      if main_line_replacement == "yes"
        main_unit = price("main_line_replacement", 1200.00)
        material_list << {
          item:       "Main Line Replacement",
          quantity:   1,
          unit:       "job",
          unit_cost:  main_unit,
          total_cost: main_unit,
          category:   "Main Line"
        }
        labor_hours += 8
      end
      if gas_line_needed == "yes"
        gas_unit = price("gas_line_install", 500.00)
        material_list << {
          item:       "Gas Line Installation",
          quantity:   1,
          unit:       "job",
          unit_cost:  gas_unit,
          total_cost: gas_unit,
          category:   "Gas"
        }
        labor_hours += 4
      end
    end

    labor_rounded = (labor_hours * 10).round / 10.0
    labor_total   = (labor_hours * @hourly_rate * 100).round / 100.0
    material_list << {
      item:       "Plumbing Labor (#{access_type} access)",
      quantity:   labor_rounded,
      unit:       "hours",
      unit_cost:  @hourly_rate,
      total_cost: labor_total,
      category:   "Labor"
    }

    total_material_cost = material_list.reject { |i| i[:category] == "Labor" }
                                       .sum { |i| i[:total_cost] }
    total_material_cost = (total_material_cost * 100).round / 100.0

    {
      trade:               "plumbing",
      total_material_cost: total_material_cost,
      labor_hours:         labor_rounded,
      material_list:       material_list
    }
  end

  def plumbing_garbage_disposal_line
    unit = price("garbage_disposal", 325.00)
    {
      item:       "Garbage Disposal Installation",
      quantity:   1,
      unit:       "unit",
      unit_cost:  unit,
      total_cost: unit,
      category:   "Add-ons"
    }
  end

  def plumbing_ice_maker_line
    unit = price("ice_maker_line", 150.00)
    {
      item:       "Ice Maker Line Installation",
      quantity:   1,
      unit:       "line",
      unit_cost:  unit,
      total_cost: unit,
      category:   "Add-ons"
    }
  end
end
