class MaterialListGenerator
  class UnsupportedTrade < StandardError; end
  class InvalidCriteria < ArgumentError; end

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
    @dominant_source = "Manual"
  end

  def call
    guard_critical_sqft!

    result = case @trade
             when "roofing"    then build_roofing
             when "plumbing"   then build_plumbing
             when "drywall"    then build_drywall
             when "flooring"   then build_flooring
             when "painting"   then build_painting
             when "siding"     then build_siding
             when "hvac"       then build_hvac
             when "electrical" then build_electrical
             else
               raise UnsupportedTrade, "trade #{@trade.inspect} not yet ported"
             end

    stamp_sources(result)
  end

  private

  # Reject non-positive sqft before any Math.sqrt / ratio math can blow up.
  # Builders that default missing sqft (e.g. plumbing "general" → service call
  # only) are allowed to pass with 0; anything explicitly negative is rejected.
  CRITICAL_SQFT_KEYS = %i[squareFeet square_feet].freeze

  def guard_critical_sqft!
    value = CRITICAL_SQFT_KEYS.map { |k| @criteria[k] }.compact.first
    return if value.nil? || value.to_s.strip.empty?

    numeric = value.to_f
    if numeric < 0
      raise InvalidCriteria, "squareFeet must be >= 0 (got #{value.inspect})"
    end
  end

  def stamp_sources(result)
    return result unless result.is_a?(Hash)

    list = Array(result[:material_list] || result["material_list"])
    list.each { |line| line[:source] ||= @dominant_source }
    result
  end

  def price(key, default)
    resolution = PricingResolver.resolve(trade: @trade, key: key, contractor_id: @contractor_id, default: default)
    # Track the last non-Manual source so line stamping reflects when we're
    # actually pulling from live pricing data. In the sandbox this is almost
    # always "Manual"; when DefaultPricing/MaterialPrice get populated the
    # result rendering will surface that automatically.
    if resolution[:source] && resolution[:source] != "Manual"
      @dominant_source = resolution[:source]
    end
    resolution[:price]
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

    # Shared fixture emission — callable from plain "fixture"/"fixture_swap"
    # branches and from "remodel" which also does rough-in. Mutates
    # material_list + labor_hours in the enclosing scope.
    emit_fixtures = lambda do
      if toilet_count > 0
        toilet_unit = price("fixture_toilet", 375.00)
        material_list << { item: "Toilet Installation",  quantity: toilet_count,  unit: "fixtures", unit_cost: toilet_unit,  total_cost: toilet_unit  * toilet_count,  category: "Fixtures" }
        labor_hours += 2.5 * toilet_count
      end
      if sink_count > 0
        sink_unit = price("fixture_sink", 450.00)
        material_list << { item: "Sink Installation",    quantity: sink_count,    unit: "fixtures", unit_cost: sink_unit,    total_cost: sink_unit    * sink_count,    category: "Fixtures" }
        labor_hours += 3 * sink_count
      end
      if faucet_count > 0
        faucet_unit = price("fixture_faucet", 262.00)
        material_list << { item: "Faucet Installation",  quantity: faucet_count,  unit: "fixtures", unit_cost: faucet_unit,  total_cost: faucet_unit  * faucet_count,  category: "Fixtures" }
        labor_hours += 1.5 * faucet_count
      end
      if tub_shower_count > 0
        tub_unit = price("fixture_tub_shower", 1200.00)
        material_list << { item: "Tub/Shower Installation", quantity: tub_shower_count, unit: "fixtures", unit_cost: tub_unit, total_cost: tub_unit * tub_shower_count, category: "Fixtures" }
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
        material_list << { item: "Dishwasher Hookup", quantity: 1, unit: "hookup", unit_cost: dw_unit, total_cost: dw_unit, category: "Add-ons" }
        labor_hours += 2
      end
    end

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

    when "rough_in"
      # Per-fixture rough plumbing: DWV + supply lines per bathroom/kitchen/laundry.
      # Keyed off room counts so controller-mapped remodel inputs flow through.
      rough_units = bathrooms + kitchens + laundry_rooms
      if rough_units > 0
        pex_unit = price("pex_pipe_lf", 2.50)
        pex_feet = (bathrooms * 40) + (kitchens * 25) + (laundry_rooms * 20)
        material_list << {
          item:       "PEX Supply Lines (rough-in)",
          quantity:   pex_feet,
          unit:       "linear feet",
          unit_cost:  pex_unit,
          total_cost: pex_feet * pex_unit,
          category:   "Pipe"
        }

        dwv_unit = price("dwv_pipe_lf", 4.25)
        dwv_feet = (bathrooms * 20) + (kitchens * 10) + (laundry_rooms * 8)
        material_list << {
          item:       "DWV Drain Lines",
          quantity:   dwv_feet,
          unit:       "linear feet",
          unit_cost:  dwv_unit,
          total_cost: dwv_feet * dwv_unit,
          category:   "Pipe"
        }

        valve_unit = price("shutoff_valve", 25.00)
        valve_count = (bathrooms * 3) + (kitchens * 2) + laundry_rooms
        material_list << {
          item:       "Shutoff Valves",
          quantity:   valve_count,
          unit:       "valves",
          unit_cost:  valve_unit,
          total_cost: valve_count * valve_unit,
          category:   "Pipe"
        }

        labor_hours += (bathrooms * 12) + (kitchens * 8) + (laundry_rooms * 5)
        labor_hours *= 1.2  if stories >= 2
        labor_hours *= access_mult
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

    when "remodel"
      # "Full remodel" — emits rough-in pipe/DWV AND fixtures in one pass.
      # Falls through to fixture branch after emitting rough-in by re-running
      # with service_type re-bound; simpler to inline the fixture block here.
      rough_units = bathrooms + kitchens + laundry_rooms
      if rough_units > 0
        pex_unit = price("pex_pipe_lf", 2.50)
        pex_feet = (bathrooms * 40) + (kitchens * 25) + (laundry_rooms * 20)
        material_list << {
          item:       "PEX Supply Lines (rough-in)",
          quantity:   pex_feet,
          unit:       "linear feet",
          unit_cost:  pex_unit,
          total_cost: pex_feet * pex_unit,
          category:   "Pipe"
        }
        dwv_unit = price("dwv_pipe_lf", 4.25)
        dwv_feet = (bathrooms * 20) + (kitchens * 10) + (laundry_rooms * 8)
        material_list << {
          item:       "DWV Drain Lines",
          quantity:   dwv_feet,
          unit:       "linear feet",
          unit_cost:  dwv_unit,
          total_cost: dwv_feet * dwv_unit,
          category:   "Pipe"
        }
        labor_hours += (bathrooms * 10) + (kitchens * 6) + (laundry_rooms * 4)
      end

      # Fall through to fixture emission.
      emit_fixtures.call
      labor_hours *= access_mult
      labor_hours = [labor_hours, 2].max

    when "fixture", "fixture_swap"
      emit_fixtures.call
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

  # -- Drywall -------------------------------------------------------------

  DRYWALL_WASTE = 1.12

  def build_drywall
    sqft          = (@criteria[:squareFeet]     || @criteria[:square_feet]     || 0).to_f
    project_type  = (@criteria[:projectType]    || @criteria[:project_type]    || "new_construction").to_s.downcase
    rooms         = (@criteria[:rooms]          || 1).to_i
    ceiling_raw   = (@criteria[:ceilingHeight]  || @criteria[:ceiling_height]  || "8ft").to_s
    ceil_height   = ceiling_raw.to_i.nonzero? || 8
    finish_level  = (@criteria[:finishLevel]    || @criteria[:finish_level]    || "level_3_standard").to_s.downcase
    texture_type  = (@criteria[:textureType]    || @criteria[:texture_type]    || "none").to_s.downcase
    damage_extent = (@criteria[:damageExtent]   || @criteria[:damage_extent]   || "minor").to_s.downcase

    sheet_half     = price("sheet_half",      12.00)
    joint_compound = price("joint_compound",  18.00)
    tape_unit      = price("tape",             8.00)
    screws_unit    = price("screws",          12.00)
    corner_bead    = price("corner_bead",      5.00)
    hang_sqft      = price("hang_sqft",        0.75)
    tape_sqft_rate = price("tape_sqft",        0.65)
    sand_sqft_rate = price("sand_sqft",        0.35)
    finish_3_mult  = price("finish_3",         1.0)
    finish_4_mult  = price("finish_4",         1.25)
    finish_5_mult  = price("finish_5",         1.50)
    tex_orange     = price("texture_orange_peel", 0.80)
    tex_knockdown  = price("texture_knockdown",   1.00)
    tex_popcorn    = price("texture_popcorn",     0.65)
    ceiling_10     = price("ceiling_10",       1.15)
    ceiling_12     = price("ceiling_12",       1.30)
    repair_minor   = price("repair_minor",   175.00)
    repair_mod     = price("repair_moderate", 400.00)
    repair_ext     = price("repair_extensive", 900.00)
    labor_rate     = @hourly_rate

    material_list = []
    labor_hours   = 0.0

    # Remodel = fresh sheets on the sqft passed in (controller multiplies
    # kitchen/bath sqft by a wall-coefficient before calling). Behaviour-wise
    # it matches new_construction math; diverging rates should land when the
    # spec-driven drywall remodel spike runs. Silent $0 is not acceptable —
    # TEA-234 smoke item #3.
    if project_type.in?(%w[new_construction remodel])
      adjusted_sqft  = sqft * DRYWALL_WASTE
      sheets_needed  = (adjusted_sqft / 32.0).ceil

      material_list << {
        item:       'Drywall Sheets (4x8, 1/2")',
        quantity:   sheets_needed,
        unit:       "sheets",
        unit_cost:  sheet_half,
        total_cost: sheets_needed * sheet_half,
        category:   "Materials"
      }

      compound_buckets = (sheets_needed / 4.0).ceil
      material_list << {
        item:       "Joint Compound",
        quantity:   compound_buckets,
        unit:       "buckets",
        unit_cost:  joint_compound,
        total_cost: compound_buckets * joint_compound,
        category:   "Materials"
      }

      tape_rolls = (sheets_needed / 8.0).ceil
      material_list << {
        item:       "Drywall Tape",
        quantity:   tape_rolls,
        unit:       "rolls",
        unit_cost:  tape_unit,
        total_cost: tape_rolls * tape_unit,
        category:   "Materials"
      }

      screw_boxes = (sheets_needed / 5.0).ceil
      material_list << {
        item:       "Drywall Screws",
        quantity:   screw_boxes,
        unit:       "boxes",
        unit_cost:  screws_unit,
        total_cost: screw_boxes * screws_unit,
        category:   "Materials"
      }

      corner_beads = (rooms * 4).ceil
      material_list << {
        item:       "Corner Beads (8ft)",
        quantity:   corner_beads,
        unit:       "pieces",
        unit_cost:  corner_bead,
        total_cost: corner_beads * corner_bead,
        category:   "Materials"
      }

      labor_cost = sqft * (hang_sqft + tape_sqft_rate + sand_sqft_rate)

      finish_mult, finish_label =
        case finish_level
        when "level_4_smooth" then [finish_4_mult, "Level 4 Smooth"]
        when "level_5_glass"  then [finish_5_mult, "Level 5 Glass"]
        else                       [finish_3_mult, "Level 3 Standard"]
        end
      labor_cost *= finish_mult

      height_label = ""
      if ceil_height >= 12
        labor_cost  *= ceiling_12
        height_label = ", 12ft+ ceilings"
      elsif ceil_height >= 10
        labor_cost  *= ceiling_10
        height_label = ", 10ft ceilings"
      end

      labor_hours = labor_cost / labor_rate

      if texture_type != "none"
        texture_rate, texture_label =
          case texture_type
          when "orange_peel" then [tex_orange,    "Orange Peel"]
          when "knockdown"   then [tex_knockdown, "Knockdown"]
          when "popcorn"     then [tex_popcorn,   "Popcorn"]
          end

        if texture_rate
          texture_cost = sqft * texture_rate
          material_list << {
            item:       "#{texture_label} Texture",
            quantity:   sqft,
            unit:       "sqft",
            unit_cost:  sqft > 0 ? texture_cost / sqft : texture_rate,
            total_cost: texture_cost,
            category:   "Texture"
          }
          labor_hours += texture_cost / labor_rate
        end
      end

      material_list << {
        item:       "Installation Labor (#{finish_label}#{height_label})",
        quantity:   (labor_hours * 10).round / 10.0,
        unit:       "hours",
        unit_cost:  labor_rate,
        total_cost: labor_hours * labor_rate,
        category:   "Labor"
      }

    elsif project_type == "repair"
      repair_cost, repair_label =
        case damage_extent
        when "moderate"   then [repair_mod,   "Moderate"]
        when "extensive"  then [repair_ext,   "Extensive"]
        else                   [repair_minor, "Minor"]
        end

      material_list << {
        item:       "Drywall Repair - #{repair_label}",
        quantity:   1,
        unit:       "job",
        unit_cost:  repair_cost,
        total_cost: repair_cost,
        category:   "Repair"
      }

      labor_hours = (repair_cost * 0.7) / labor_rate

      if texture_type != "none"
        repair_sqft = [sqft, 100].min
        texture_rate, texture_label =
          case texture_type
          when "orange_peel" then [tex_orange,    "Orange Peel"]
          when "knockdown"   then [tex_knockdown, "Knockdown"]
          when "popcorn"     then [tex_popcorn,   "Popcorn"]
          end

        if texture_rate && repair_sqft > 0
          texture_cost = repair_sqft * texture_rate
          material_list << {
            item:       "#{texture_label} Texture Match",
            quantity:   repair_sqft,
            unit:       "sqft",
            unit_cost:  texture_cost / repair_sqft,
            total_cost: texture_cost,
            category:   "Texture"
          }
          labor_hours += texture_cost / labor_rate
        end
      end
    end

    total_material_cost = material_list.reject { |i| i[:category] == "Labor" }
                                       .sum { |i| i[:total_cost] }
    total_material_cost = (total_material_cost * 100).round / 100.0

    {
      trade:               "drywall",
      total_material_cost: total_material_cost,
      labor_hours:         (labor_hours * 10).round / 10.0,
      material_list:       material_list
    }
  end

  # -- Flooring ------------------------------------------------------------

  FLOORING_WASTE = 1.10

  FLOORING_LABEL = {
    "carpet"         => "Carpet",
    "vinyl"          => "Vinyl",
    "laminate"       => "Laminate",
    "lvp"            => "Lvp",
    "hardwood_eng"   => "Hardwood Eng",
    "hardwood_solid" => "Hardwood Solid",
    "tile_ceramic"   => "Tile Ceramic",
    "tile_porcelain" => "Tile Porcelain"
  }.freeze

  def build_flooring
    sqft            = (@criteria[:squareFeet]      || @criteria[:square_feet]      || 0).to_f
    flooring_type   = (@criteria[:flooringType]    || @criteria[:flooring_type]    || "carpet").to_s.downcase
    removal         = truthy?(@criteria[:removal])
    subfloor_repair = truthy?(@criteria[:subfloorRepair] || @criteria[:subfloor_repair])
    underlayment_on = @criteria.key?(:underlayment) ? truthy?(@criteria[:underlayment]) : true
    baseboard_lf    = (@criteria[:baseboard] || 0).to_f
    complexity      = (@criteria[:complexity] || "standard").to_s.downcase

    material_costs = {
      "carpet"         => price("floor_carpet",         5.00),
      "vinyl"          => price("floor_vinyl",          3.50),
      "laminate"       => price("floor_laminate",       4.00),
      "lvp"            => price("floor_lvp",            4.50),
      "hardwood_eng"   => price("floor_hardwood_eng",  10.00),
      "hardwood_solid" => price("floor_hardwood_solid",14.00),
      "tile_ceramic"   => price("floor_tile_ceramic",   7.50),
      "tile_porcelain" => price("floor_tile_porcelain",10.00)
    }

    labor_rates = {
      "carpet"         => price("floor_labor_carpet",   2.00),
      "vinyl"          => price("floor_labor_vinyl",    2.50),
      "laminate"       => price("floor_labor_vinyl",    2.50),
      "lvp"            => price("floor_labor_vinyl",    2.50),
      "hardwood_eng"   => price("floor_labor_hardwood", 5.00),
      "hardwood_solid" => price("floor_labor_hardwood", 5.00),
      "tile_ceramic"   => price("floor_labor_tile",     6.50),
      "tile_porcelain" => price("floor_labor_tile",     6.50)
    }

    adjusted_sqft = sqft * FLOORING_WASTE
    cost_per_sqft = material_costs[flooring_type] || price("floor_vinyl", 3.50)

    material_list = []

    label = FLOORING_LABEL[flooring_type] ||
            flooring_type.split("_").map(&:capitalize).join(" ")
    material_list << {
      item:       "#{label} Flooring",
      quantity:   adjusted_sqft.ceil,
      unit:       "sqft",
      unit_cost:  cost_per_sqft,
      total_cost: adjusted_sqft * cost_per_sqft,
      category:   "flooring_material"
    }

    if underlayment_on && flooring_type != "carpet"
      u_cost = price("floor_underlay", 0.50)
      material_list << {
        item:       "Underlayment",
        quantity:   sqft,
        unit:       "sqft",
        unit_cost:  u_cost,
        total_cost: sqft * u_cost,
        category:   "underlayment"
      }
    end

    if removal
      r_cost = price("floor_removal", 2.00)
      material_list << {
        item:       "Old Flooring Removal",
        quantity:   sqft,
        unit:       "sqft",
        unit_cost:  r_cost,
        total_cost: sqft * r_cost,
        category:   "removal"
      }
    end

    if subfloor_repair
      s_cost     = price("floor_subfloor", 4.00)
      repair_sqft = (sqft * 0.3).ceil
      material_list << {
        item:       "Subfloor Repair",
        quantity:   repair_sqft,
        unit:       "sqft",
        unit_cost:  s_cost,
        total_cost: repair_sqft * s_cost,
        category:   "prep"
      }
    end

    if baseboard_lf > 0
      b_cost = price("floor_baseboard", 5.00)
      material_list << {
        item:       "Baseboard Trim",
        quantity:   baseboard_lf,
        unit:       "linear feet",
        unit_cost:  b_cost,
        total_cost: baseboard_lf * b_cost,
        category:   "trim"
      }
    end

    complexity_mult = {
      "standard" => price("floor_standard", 1.0),
      "moderate" => price("floor_moderate", 1.2),
      "complex"  => price("floor_complex",  1.4)
    }

    labor_rate = labor_rates[flooring_type] || price("floor_labor_vinyl", 2.50)

    # Legacy JS divides by a fixed 45, not @hourly_rate. Preserve verbatim.
    labor_hours  = (sqft * labor_rate) / 45.0
    labor_hours *= (complexity_mult[complexity] || 1.0)
    labor_hours += sqft * 0.02 if removal
    labor_hours += sqft * 0.01 if subfloor_repair
    labor_hours += baseboard_lf / 20.0 if baseboard_lf > 0

    total_material_cost = material_list.reject { |i| i[:category] == "Labor" }
                                       .sum { |i| i[:total_cost] }

    {
      trade:               "flooring",
      total_material_cost: (total_material_cost * 100).round / 100.0,
      labor_hours:         (labor_hours * 100).round / 100.0,
      material_list:       material_list
    }
  end

  # -- Painting ------------------------------------------------------------

  COAT_MULTIPLIER  = { 1 => 1.0, 2 => 1.5, 3 => 2.0 }.freeze
  STORY_MULTIPLIER = { 1 => 1.0, 2 => 1.15, 3 => 1.35, 4 => 1.5 }.freeze
  PAINT_CONDITION_MULTIPLIER = {
    "excellent" => 0.9, "good" => 1.0, "smooth" => 1.0,
    "fair" => 1.15,     "textured" => 1.1,
    "poor" => 1.25,     "damaged" => 1.35, "needs_repair" => 1.4
  }.freeze

  def build_painting
    sqft          = (@criteria[:squareFeet]      || @criteria[:square_feet]      || 0).to_f
    paint_type    = (@criteria[:paintType]       || @criteria[:paint_type]       || "exterior").to_s.downcase
    stories       = (@criteria[:stories] || 1).to_i
    coats         = (@criteria[:coats]   || 2).to_i
    include_ceil  = (@criteria[:includeCeilings] || @criteria[:include_ceilings] || "no").to_s.downcase
    trim_lf       = (@criteria[:trimLinearFeet]  || @criteria[:trim_linear_feet] || 0).to_f
    doors         = (@criteria[:doorCount]       || @criteria[:door_count]       || 0).to_i
    windows       = (@criteria[:windowCount]     || @criteria[:window_count]     || 0).to_i
    siding_cond   = (@criteria[:sidingCondition] || @criteria[:siding_condition] || "good").to_s.downcase
    power_wash    = (@criteria[:powerWashing]    || @criteria[:power_washing]    || "no").to_s.downcase
    wall_cond     = (@criteria[:wallCondition]   || @criteria[:wall_condition]   || "smooth").to_s.downcase
    patching      = (@criteria[:patchingNeeded]  || @criteria[:patching_needed]  || "none").to_s.downcase
    lead_paint    = (@criteria[:leadPaint]       || @criteria[:lead_paint]       || "no").to_s.downcase
    color_change  = (@criteria[:colorChangeDramatic] || @criteria[:color_change_dramatic] || "no").to_s.downcase

    ext_mat_rate    = price("paint_exterior_mat",         0.45)
    ext_labor_rate  = price("paint_exterior_labor",       2.50)
    int_mat_rate    = price("paint_interior_mat",         0.45)
    int_labor_rate  = price("paint_interior_labor",       3.50)
    ceil_mat_rate   = price("paint_ceiling_mat",          0.35)
    ceil_labor_rate = price("paint_ceiling_labor",        1.25)
    trim_mat_rate   = price("paint_trim_mat",             0.50)
    trim_labor_rate = price("paint_trim_labor",           2.00)
    door_mat_rate   = price("paint_door_mat",            15.00)
    door_labor_rate = price("paint_door_labor",          60.00)
    win_mat_rate    = price("paint_window_mat",          10.00)
    win_labor_rate  = price("paint_window_labor",        40.00)
    pw_mat_rate     = price("paint_power_wash_mat",       0.10)
    pw_labor_rate   = price("paint_power_wash_labor",     0.15)
    patch_min_mat   = price("paint_patch_minor_mat",     50.00)
    patch_min_lab   = price("paint_patch_minor_labor",  100.00)
    patch_mod_mat   = price("paint_patch_moderate_mat", 100.00)
    patch_mod_lab   = price("paint_patch_moderate_labor", 250.00)
    patch_ext_mat   = price("paint_patch_extensive_mat", 250.00)
    patch_ext_lab   = price("paint_patch_extensive_labor", 500.00)
    primer_mat_rate = price("paint_primer_mat",           0.20)
    primer_lab_rate = price("paint_primer_labor",         0.30)
    lead_mat_rate   = price("paint_lead_mat",           150.00)
    lead_lab_rate   = price("paint_lead_labor",         350.00)

    coat_mult  = COAT_MULTIPLIER.fetch(coats, 1.5)
    story_mult = STORY_MULTIPLIER.fetch(stories, 1.0)

    material_list    = []
    total_labor_cost = 0.0

    # ----- Interior -----
    if %w[interior both].include?(paint_type)
      int_sqft  = paint_type == "both" ? sqft * 0.5 : sqft
      cond_mult = PAINT_CONDITION_MULTIPLIER.fetch(wall_cond, 1.0)
      plural    = coats > 1 ? "s" : ""

      int_mat_cost = int_sqft * int_mat_rate * coat_mult
      material_list << {
        item:       "Interior Paint Materials (#{coats} coat#{plural})",
        quantity:   int_sqft,
        unit:       "sqft",
        unit_cost:  (int_mat_rate * coat_mult * 100).round / 100.0,
        total_cost: (int_mat_cost * 100).round / 100.0,
        category:   "Interior"
      }

      int_labor_cost = int_sqft * int_labor_rate * coat_mult * cond_mult
      material_list << {
        item:       "Interior Labor (#{coats} coat#{plural})",
        quantity:   int_sqft,
        unit:       "sqft",
        unit_cost:  (int_labor_rate * coat_mult * cond_mult * 100).round / 100.0,
        total_cost: (int_labor_cost * 100).round / 100.0,
        category:   "Labor"
      }
      total_labor_cost += int_labor_cost

      if include_ceil == "yes"
        ceil_sqft       = int_sqft * 0.9
        ceil_mat_cost   = ceil_sqft * ceil_mat_rate   * coat_mult
        ceil_labor_cost = ceil_sqft * ceil_labor_rate * coat_mult

        material_list << {
          item:       "Ceiling Paint Materials",
          quantity:   ceil_sqft.round,
          unit:       "sqft",
          unit_cost:  (ceil_mat_rate * coat_mult * 100).round / 100.0,
          total_cost: (ceil_mat_cost * 100).round / 100.0,
          category:   "Interior"
        }
        material_list << {
          item:       "Ceiling Labor",
          quantity:   ceil_sqft.round,
          unit:       "sqft",
          unit_cost:  (ceil_labor_rate * coat_mult * 100).round / 100.0,
          total_cost: (ceil_labor_cost * 100).round / 100.0,
          category:   "Labor"
        }
        total_labor_cost += ceil_labor_cost
      end
    end

    # ----- Exterior -----
    if %w[exterior both].include?(paint_type)
      ext_sqft  = paint_type == "both" ? sqft * 0.5 : sqft
      cond_mult = PAINT_CONDITION_MULTIPLIER.fetch(siding_cond, 1.0)
      coat_s    = coats > 1 ? "s" : ""
      story_s   = stories > 1 ? "ies" : "y"

      ext_mat_cost   = ext_sqft * ext_mat_rate   * coat_mult * story_mult
      ext_labor_cost = ext_sqft * ext_labor_rate * coat_mult * story_mult * cond_mult

      material_list << {
        item:       "Exterior Paint Materials (#{coats} coat#{coat_s}, #{stories} stor#{story_s})",
        quantity:   ext_sqft,
        unit:       "sqft",
        unit_cost:  (ext_mat_rate * coat_mult * story_mult * 100).round / 100.0,
        total_cost: (ext_mat_cost * 100).round / 100.0,
        category:   "Exterior"
      }
      material_list << {
        item:       "Exterior Labor (#{coats} coat#{coat_s}, #{stories} stor#{story_s})",
        quantity:   ext_sqft,
        unit:       "sqft",
        unit_cost:  (ext_labor_rate * coat_mult * story_mult * cond_mult * 100).round / 100.0,
        total_cost: (ext_labor_cost * 100).round / 100.0,
        category:   "Labor"
      }
      total_labor_cost += ext_labor_cost

      if power_wash == "yes"
        pw_mat_cost   = ext_sqft * pw_mat_rate
        pw_labor_cost = ext_sqft * pw_labor_rate

        material_list << {
          item:       "Power Washing Materials",
          quantity:   ext_sqft,
          unit:       "sqft",
          unit_cost:  pw_mat_rate,
          total_cost: (pw_mat_cost * 100).round / 100.0,
          category:   "Prep"
        }
        material_list << {
          item:       "Power Washing Labor",
          quantity:   ext_sqft,
          unit:       "sqft",
          unit_cost:  pw_labor_rate,
          total_cost: (pw_labor_cost * 100).round / 100.0,
          category:   "Labor"
        }
        total_labor_cost += pw_labor_cost
      end
    end

    # ----- Patching -----
    case patching
    when "minor"
      material_list << { item: "Wall Patching Materials (minor)",    quantity: 1, unit: "job", unit_cost: patch_min_mat, total_cost: patch_min_mat, category: "Prep" }
      material_list << { item: "Wall Patching Labor (minor)",        quantity: 1, unit: "job", unit_cost: patch_min_lab, total_cost: patch_min_lab, category: "Labor" }
      total_labor_cost += patch_min_lab
    when "moderate"
      material_list << { item: "Wall Patching Materials (moderate)", quantity: 1, unit: "job", unit_cost: patch_mod_mat, total_cost: patch_mod_mat, category: "Prep" }
      material_list << { item: "Wall Patching Labor (moderate)",     quantity: 1, unit: "job", unit_cost: patch_mod_lab, total_cost: patch_mod_lab, category: "Labor" }
      total_labor_cost += patch_mod_lab
    when "extensive"
      material_list << { item: "Wall Patching Materials (extensive)", quantity: 1, unit: "job", unit_cost: patch_ext_mat, total_cost: patch_ext_mat, category: "Prep" }
      material_list << { item: "Wall Patching Labor (extensive)",     quantity: 1, unit: "job", unit_cost: patch_ext_lab, total_cost: patch_ext_lab, category: "Labor" }
      total_labor_cost += patch_ext_lab
    end

    # ----- Trim / Doors / Windows -----
    if trim_lf > 0
      material_list << { item: "Trim Materials", quantity: trim_lf, unit: "linear ft", unit_cost: trim_mat_rate,   total_cost: (trim_lf * trim_mat_rate   * 100).round / 100.0, category: "Trim & Detail" }
      material_list << { item: "Trim Labor",     quantity: trim_lf, unit: "linear ft", unit_cost: trim_labor_rate, total_cost: (trim_lf * trim_labor_rate * 100).round / 100.0, category: "Labor" }
      total_labor_cost += trim_lf * trim_labor_rate
    end

    if doors > 0
      material_list << { item: "Door Painting Materials", quantity: doors, unit: "doors", unit_cost: door_mat_rate,   total_cost: doors * door_mat_rate,   category: "Trim & Detail" }
      material_list << { item: "Door Painting Labor",     quantity: doors, unit: "doors", unit_cost: door_labor_rate, total_cost: doors * door_labor_rate, category: "Labor" }
      total_labor_cost += doors * door_labor_rate
    end

    if windows > 0
      material_list << { item: "Window Trim Materials", quantity: windows, unit: "windows", unit_cost: win_mat_rate,   total_cost: windows * win_mat_rate,   category: "Trim & Detail" }
      material_list << { item: "Window Trim Labor",     quantity: windows, unit: "windows", unit_cost: win_labor_rate, total_cost: windows * win_labor_rate, category: "Labor" }
      total_labor_cost += windows * win_labor_rate
    end

    # ----- Primer for dramatic color change -----
    if color_change == "yes"
      material_list << { item: "Extra Primer Materials (Color Change)", quantity: sqft, unit: "sqft", unit_cost: primer_mat_rate, total_cost: (sqft * primer_mat_rate * 100).round / 100.0, category: "Prep" }
      material_list << { item: "Extra Primer Labor (Color Change)",     quantity: sqft, unit: "sqft", unit_cost: primer_lab_rate, total_cost: (sqft * primer_lab_rate * 100).round / 100.0, category: "Labor" }
      total_labor_cost += sqft * primer_lab_rate
    end

    # ----- Lead abatement -----
    if lead_paint == "yes"
      material_list << { item: "Lead Paint Abatement Materials", quantity: 1, unit: "job", unit_cost: lead_mat_rate, total_cost: lead_mat_rate, category: "Specialty" }
      material_list << { item: "Lead Paint Abatement Labor",     quantity: 1, unit: "job", unit_cost: lead_lab_rate, total_cost: lead_lab_rate, category: "Labor" }
      total_labor_cost += lead_lab_rate
    end

    total_material_cost = material_list.reject { |i| i[:category] == "Labor" }
                                       .sum { |i| i[:total_cost] }

    # Painting prices labor per-sqft / per-unit, not per-hour. Surface an
    # equivalent-hours rollup so the totals card + remodel-summary rollup
    # don't under-report (TEA-234 smoke item #5).
    equivalent_hours = @hourly_rate.to_f.positive? ? (total_labor_cost / @hourly_rate) : 0.0

    {
      trade:               "painting",
      total_material_cost: (total_material_cost * 100).round / 100.0,
      labor_hours:         (equivalent_hours * 10).round / 10.0,
      labor_cost:          (total_labor_cost * 100).round / 100.0,
      material_list:       material_list
    }
  end

  # -- Siding --------------------------------------------------------------

  SIDING_WASTE = 1.12

  SIDING_LABEL = {
    "vinyl"        => "Vinyl",
    "fiber_cement" => "Fiber Cement",
    "wood"         => "Wood",
    "metal"        => "Metal",
    "stucco"       => "Stucco"
  }.freeze

  def build_siding
    sqft       = (@criteria[:squareFeet] || @criteria[:square_feet] || 0).to_f
    raw_type   = (@criteria[:sidingType]  || @criteria[:siding_type] || "vinyl").to_s.downcase
    stories    = (@criteria[:stories] || 1).to_i
    removal_in = @criteria[:removal]
    needs_rem  = (@criteria[:needsRemoval] || @criteria[:needs_removal]).to_s.downcase
    windows    = (@criteria[:windowCount]  || @criteria[:window_count] || 0).to_i
    doors      = (@criteria[:doorCount]    || @criteria[:door_count]   || 0).to_i
    trim_in    = @criteria[:trimLinearFeet] || @criteria[:trim_linear_feet]

    siding_type = case raw_type
                  when "wood_cedar"     then "wood"
                  when "metal_aluminum" then "metal"
                  else                       raw_type
                  end

    removal = truthy?(removal_in) || needs_rem == "yes"

    material_costs = {
      "vinyl"        => price("siding_vinyl",        5.50),
      "fiber_cement" => price("siding_fiber_cement", 9.50),
      "wood"         => price("siding_wood",        14.00),
      "metal"        => price("siding_metal",        8.00),
      "stucco"       => price("siding_stucco",      11.00)
    }

    labor_rates = {
      "vinyl"        => price("siding_labor_vinyl",  3.50),
      "fiber_cement" => price("siding_labor_fiber",  5.50),
      "wood"         => price("siding_labor_wood",   6.50),
      "metal"        => price("siding_labor_metal",  4.50),
      "stucco"       => price("siding_labor_stucco", 7.50)
    }

    adjusted_sqft = sqft * SIDING_WASTE
    trim          = trim_in.nil? ? Math.sqrt(sqft) * 4 : trim_in.to_f

    cost_per_sqft = material_costs[siding_type] || price("siding_vinyl", 5.50)

    material_list = []

    label = SIDING_LABEL[siding_type] ||
            siding_type.split("_").map(&:capitalize).join(" ")
    material_list << {
      item:       "#{label} Siding",
      quantity:   adjusted_sqft.ceil,
      unit:       "sqft",
      unit_cost:  cost_per_sqft,
      total_cost: adjusted_sqft * cost_per_sqft,
      category:   "siding_material"
    }

    house_wrap_cost  = price("siding_housewrap_roll", 175.00)
    house_wrap_rolls = (sqft / 1000.0).ceil
    material_list << {
      item:       "House Wrap",
      quantity:   house_wrap_rolls,
      unit:       "rolls",
      unit_cost:  house_wrap_cost,
      total_cost: house_wrap_rolls * house_wrap_cost,
      category:   "house_wrap"
    }

    j_channel_cost   = price("siding_j_channel", 12.00)
    j_channel_pieces = (trim / 12.0).ceil
    material_list << {
      item:       "J-Channel",
      quantity:   j_channel_pieces,
      unit:       "pieces (12ft)",
      unit_cost:  j_channel_cost,
      total_cost: j_channel_pieces * j_channel_cost,
      category:   "trim"
    }

    corner_post_cost = price("siding_corner_post", 35.00)
    corner_posts     = stories <= 1 ? 6 : stories * 6
    material_list << {
      item:       "Corner Posts",
      quantity:   corner_posts,
      unit:       "posts",
      unit_cost:  corner_post_cost,
      total_cost: corner_posts * corner_post_cost,
      category:   "trim"
    }

    if windows > 0
      w_cost = price("siding_window_trim", 55.00)
      material_list << {
        item:       "Window Trim & Wrapping",
        quantity:   windows,
        unit:       "windows",
        unit_cost:  w_cost,
        total_cost: windows * w_cost,
        category:   "trim"
      }
    end

    if doors > 0
      d_cost = price("siding_door_trim", 75.00)
      material_list << {
        item:       "Door Trim & Wrapping",
        quantity:   doors,
        unit:       "doors",
        unit_cost:  d_cost,
        total_cost: doors * d_cost,
        category:   "trim"
      }
    end

    perimeter    = Math.sqrt(sqft) * 4
    soffit_sqft  = perimeter * 1.5
    soffit_cost  = price("siding_soffit_sqft", 8.00)
    material_list << {
      item:       "Soffit",
      quantity:   soffit_sqft.ceil,
      unit:       "sqft",
      unit_cost:  soffit_cost,
      total_cost: soffit_sqft * soffit_cost,
      category:   "soffit"
    }

    fascia_cost = price("siding_fascia_lf", 6.00)
    material_list << {
      item:       "Fascia",
      quantity:   perimeter.ceil,
      unit:       "linear ft",
      unit_cost:  fascia_cost,
      total_cost: perimeter * fascia_cost,
      category:   "fascia"
    }

    kit_cost = price("siding_fastener_kit", 175.00)
    material_list << {
      item:       "Fasteners, Flashing & Caulk",
      quantity:   1,
      unit:       "kit",
      unit_cost:  kit_cost,
      total_cost: kit_cost,
      category:   "fasteners"
    }

    if removal
      rem_cost = price("siding_removal_sqft", 1.75)
      material_list << {
        item:       "Old Siding Removal & Disposal",
        quantity:   sqft,
        unit:       "sqft",
        unit_cost:  rem_cost,
        total_cost: sqft * rem_cost,
        category:   "removal"
      }
    end

    # Labor
    labor_rate       = labor_rates[siding_type] || price("siding_labor_vinyl", 3.50)
    labor_hourly_rate = price("siding_labor_rate", 45.00)
    labor_hours      = (sqft * labor_rate) / labor_hourly_rate

    story2_mult = price("siding_story_2", 1.25)
    story3_mult = price("siding_story_3", 1.50)
    if stories >= 3
      labor_hours *= story3_mult
    elsif stories >= 2
      labor_hours *= story2_mult
    end
    labor_hours += sqft * 0.02 if removal

    total_material_cost = material_list.reject { |i| i[:category] == "Labor" }
                                       .sum { |i| i[:total_cost] }

    {
      trade:               "siding",
      total_material_cost: (total_material_cost * 100).round / 100.0,
      labor_hours:         (labor_hours * 100).round / 100.0,
      material_list:       material_list
    }
  end

  # -- HVAC ----------------------------------------------------------------

  HVAC_EQUIPMENT_NAMES = {
    "furnace"   => { "standard" => "Standard Furnace",     "high" => "High-Efficiency Furnace" },
    "ac"        => { "standard" => "Central AC Unit",      "high" => "High-Efficiency AC Unit" },
    "heatpump"  => { "standard" => "Heat Pump",            "high" => "High-Efficiency Heat Pump" },
    "minisplit" => { "standard" => "Mini-Split System",    "high" => "Mini-Split System" }
  }.freeze

  def build_hvac
    sqft        = (@criteria[:squareFeet] || @criteria[:square_feet] || 0).to_f
    system_type = (@criteria[:systemType]  || @criteria[:system_type] || "furnace").to_s.downcase
    efficiency  = (@criteria[:efficiency]  || "standard").to_s.downcase
    ductwork    = (@criteria[:ductwork]    || "existing").to_s.downcase
    stories     = (@criteria[:stories] || 1).to_i
    zones       = (@criteria[:zoneCount]   || @criteria[:zone_count]   || 1).to_i
    thermostats = (@criteria[:thermostats] || 1).to_i

    size_small  = price("hvac_size_small",  0.9)
    size_med    = price("hvac_size_med",    1.0)
    size_large  = price("hvac_size_large",  1.2)
    size_xlarge = price("hvac_size_xlarge", 1.4)

    size_mult = if    sqft <  1500 then size_small
                elsif sqft <= 2500 then size_med
                elsif sqft <= 4000 then size_large
                else                    size_xlarge
                end

    equipment_prices = {
      "furnace"   => { "standard" => price("hvac_furnace_standard",  3500.00),
                       "high"     => price("hvac_furnace_high",      4500.00) },
      "ac"        => { "standard" => price("hvac_ac_standard",       4000.00),
                       "high"     => price("hvac_ac_high",           5500.00) },
      "heatpump"  => { "standard" => price("hvac_heatpump_standard", 5500.00),
                       "high"     => price("hvac_heatpump_high",     7500.00) },
      "minisplit" => { "standard" => price("hvac_minisplit",         2500.00),
                       "high"     => price("hvac_minisplit",         2500.00) }
    }

    equipment_cost = equipment_prices.dig(system_type, efficiency) ||
                     price("hvac_furnace_standard", 3500.00)
    equipment_cost *= zones if system_type == "minisplit"
    equipment_cost *= size_mult

    equipment_name = if system_type == "minisplit"
                       "Mini-Split System (#{zones} zones)"
                     else
                       HVAC_EQUIPMENT_NAMES.dig(system_type, efficiency) || "HVAC Unit"
                     end

    material_list = []
    material_list << {
      item:       equipment_name,
      quantity:   1,
      unit:       "unit",
      unit_cost:  equipment_cost,
      total_cost: equipment_cost,
      category:   "hvac_units"
    }

    ductwork_feet = 0
    case ductwork
    when "new"
      d_cost = price("hvac_duct_new", 15.00)
      ductwork_feet = (sqft / 10.0).ceil
      material_list << {
        item:       "New Ductwork",
        quantity:   ductwork_feet,
        unit:       "linear feet",
        unit_cost:  d_cost,
        total_cost: ductwork_feet * d_cost,
        category:   "ductwork"
      }
    when "repair"
      d_cost = price("hvac_duct_repair", 8.00)
      ductwork_feet = (sqft / 20.0).ceil
      material_list << {
        item:       "Ductwork Repair",
        quantity:   ductwork_feet,
        unit:       "linear feet",
        unit_cost:  d_cost,
        total_cost: ductwork_feet * d_cost,
        category:   "ductwork"
      }
    end

    thermo_cost = price("hvac_thermostat", 350.00)
    material_list << {
      item:       "Smart Thermostat",
      quantity:   thermostats,
      unit:       "units",
      unit_cost:  thermo_cost,
      total_cost: thermostats * thermo_cost,
      category:   "thermostats"
    }

    if system_type != "furnace"
      r_cost = price("hvac_refrigerant", 250.00)
      material_list << {
        item:       "Refrigerant",
        quantity:   1,
        unit:       "charge",
        unit_cost:  r_cost,
        total_cost: r_cost,
        category:   "refrigerant"
      }
    end

    filter_cost = price("hvac_filters", 200.00)
    material_list << {
      item:       "Filters & Supplies",
      quantity:   1,
      unit:       "set",
      unit_cost:  filter_cost,
      total_cost: filter_cost,
      category:   "filters"
    }

    base_labor = {
      "furnace"   => price("hvac_labor_furnace",   12.00),
      "ac"        => price("hvac_labor_ac",        10.00),
      "heatpump"  => price("hvac_labor_heatpump",  14.00),
      "minisplit" => price("hvac_labor_minisplit", 8.00)
    }

    labor_hours  = base_labor[system_type] || 10.0
    labor_hours *= zones if system_type == "minisplit"
    labor_hours += ductwork_feet / 20.0 if ductwork == "new"
    labor_hours += ductwork_feet / 30.0 if ductwork == "repair"

    story2_mult = price("hvac_story_2", 1.2)
    story3_mult = price("hvac_story_3", 1.4)
    if stories >= 3
      labor_hours *= story3_mult
    elsif stories >= 2
      labor_hours *= story2_mult
    end

    total_material_cost = material_list.reject { |i| i[:category] == "Labor" }
                                       .sum { |i| i[:total_cost] }

    {
      trade:               "hvac",
      total_material_cost: (total_material_cost * 100).round / 100.0,
      labor_hours:         (labor_hours * 100).round / 100.0,
      material_list:       material_list
    }
  end

  # -- Electrical ----------------------------------------------------------

  ELECTRICAL_AVG_RUN_PER_DEVICE = 25
  ELECTRICAL_PANEL_MISC  = { "100" => 200, "200" => 250, "400" => 400 }.freeze
  ELECTRICAL_PANEL_LABOR = { "100" => 8,   "200" => 10,  "400" => 16  }.freeze

  def build_electrical
    sqft = (@criteria[:squareFootage] ||
            @criteria[:square_footage] ||
            @criteria[:squareFeet] ||
            @criteria[:square_feet] || 0).to_f

    service_type = (@criteria[:serviceType] || @criteria[:service_type] || "general").to_s.downcase
    amperage     = (@criteria[:amperage] || "200").to_s
    home_age     = (@criteria[:homeAge] || @criteria[:home_age] || "1990+").to_s
    stories      = (@criteria[:stories] || 1).to_i

    outlet_count    = (@criteria[:outletCount]     || @criteria[:outlet_count]     || 0).to_i
    gfci_count      = (@criteria[:gfciCount]       || @criteria[:gfci_count]       || 0).to_i
    switch_count    = (@criteria[:switchCount]     || @criteria[:switch_count]     || 0).to_i
    dimmer_count    = (@criteria[:dimmerCount]     || @criteria[:dimmer_count]     || 0).to_i
    fixture_count   = (@criteria[:fixtureCount]    || @criteria[:fixture_count]    || 0).to_i
    recessed_count  = (@criteria[:recessedCount]   || @criteria[:recessed_count]   || 0).to_i
    ceiling_fans    = (@criteria[:ceilingFanCount] || @criteria[:ceiling_fan_count] || 0).to_i
    circuits_20a    = (@criteria[:circuits20a] || @criteria[:circuits_20a] || 0).to_i
    circuits_30a    = (@criteria[:circuits30a] || @criteria[:circuits_30a] || 0).to_i
    circuits_50a    = (@criteria[:circuits50a] || @criteria[:circuits_50a] || 0).to_i

    ev_charger = (@criteria[:evCharger] || @criteria[:ev_charger]).to_s.downcase
    permit_val = @criteria[:permit]

    labor_rate = @hourly_rate
    wire_lf    = price("elec_wire_lf", 1.00)
    avg_run    = ELECTRICAL_AVG_RUN_PER_DEVICE

    age_multiplier = case home_age
                     when "pre-1960"  then 2.0
                     when "1960-1990" then 1.25
                     else                  1.0
                     end

    story_multiplier = if stories >= 3 then 1.35
                       elsif stories == 2 then 1.15
                       else 1.0
                       end

    complexity_multiplier = age_multiplier * story_multiplier
    total_labor_hours = 0.0

    panel_costs = {
      "100" => price("elec_panel_100", 450.00),
      "200" => price("elec_panel_200", 550.00),
      "400" => price("elec_panel_400", 1200.00)
    }

    material_list = []

    if service_type == "panel"
      panel_hours = ELECTRICAL_PANEL_LABOR[amperage] || 10
      total_labor_hours += panel_hours
      panel_cost = panel_costs[amperage] || panel_costs["200"]
      panel_misc = ELECTRICAL_PANEL_MISC[amperage] || 250
      material_list << {
        item:       "#{amperage}A Panel Upgrade",
        quantity:   1,
        unit:       "each",
        unit_cost:  panel_cost,
        total_cost: panel_cost,
        category:   "Panel"
      }
      material_list << {
        item:       "Breakers, Connectors & Misc",
        quantity:   1,
        unit:       "lot",
        unit_cost:  panel_misc,
        total_cost: panel_misc,
        category:   "Panel"
      }
    end

    if service_type == "rewire"
      rewire_sqft_price = price("elec_rewire_sqft", 11.50)
      rewire_total = sqft * rewire_sqft_price
      rewire_hours = (sqft / 100.0) * 4
      total_labor_hours += rewire_hours + (ELECTRICAL_PANEL_LABOR[amperage] || 10)

      panel_cost = panel_costs[amperage] || panel_costs["200"]
      panel_misc = ELECTRICAL_PANEL_MISC[amperage] || 250

      material_list << {
        item:       "Full Rewire (#{sqft} sqft)",
        quantity:   sqft,
        unit:       "sqft",
        unit_cost:  rewire_sqft_price,
        total_cost: rewire_total,
        category:   "Rewire"
      }
      material_list << {
        item:       "#{amperage}A Panel",
        quantity:   1,
        unit:       "each",
        unit_cost:  panel_cost,
        total_cost: panel_cost,
        category:   "Panel"
      }
      material_list << {
        item:       "Breakers, Connectors & Misc",
        quantity:   1,
        unit:       "lot",
        unit_cost:  panel_misc,
        total_cost: panel_misc,
        category:   "Panel"
      }
    end

    if service_type == "circuits" || service_type == "general"
      if ceiling_fans > 0
        install = price("elec_ceiling_fan_install", 200.00)
        hardware = 15
        wire_cost = avg_run * wire_lf
        unit_cost = install + hardware + wire_cost
        material_list << {
          item:       "Ceiling Fan Install (labor + hardware + wire)",
          quantity:   ceiling_fans,
          unit:       "each",
          unit_cost:  unit_cost,
          total_cost: ceiling_fans * unit_cost,
          category:   "Lighting"
        }
        total_labor_hours += ceiling_fans * (install / labor_rate)
      end

      if outlet_count > 0
        p = price("elec_outlet", 12.00)
        wire_cost = avg_run * wire_lf
        unit_cost = p + wire_cost
        material_list << {
          item:       "Standard Outlets (w/ wire)",
          quantity:   outlet_count,
          unit:       "each",
          unit_cost:  unit_cost,
          total_cost: outlet_count * unit_cost,
          category:   "Outlets"
        }
        total_labor_hours += outlet_count * 0.75
      end

      if gfci_count > 0
        p = price("elec_outlet_gfci", 35.00)
        wire_cost = avg_run * wire_lf
        unit_cost = p + wire_cost
        material_list << {
          item:       "GFCI Outlets (w/ wire)",
          quantity:   gfci_count,
          unit:       "each",
          unit_cost:  unit_cost,
          total_cost: gfci_count * unit_cost,
          category:   "Outlets"
        }
        total_labor_hours += gfci_count * 1.0
      end

      if switch_count > 0
        p = price("elec_switch", 10.00)
        wire_cost = avg_run * wire_lf
        unit_cost = p + wire_cost
        material_list << {
          item:       "Standard Switches (w/ wire)",
          quantity:   switch_count,
          unit:       "each",
          unit_cost:  unit_cost,
          total_cost: switch_count * unit_cost,
          category:   "Switches"
        }
        total_labor_hours += switch_count * 0.5
      end

      if dimmer_count > 0
        p = price("elec_switch_dimmer", 50.00)
        wire_cost = avg_run * wire_lf
        unit_cost = p + wire_cost
        material_list << {
          item:       "Dimmer Switches (w/ wire)",
          quantity:   dimmer_count,
          unit:       "each",
          unit_cost:  unit_cost,
          total_cost: dimmer_count * unit_cost,
          category:   "Switches"
        }
        total_labor_hours += dimmer_count * 0.75
      end

      if fixture_count > 0
        install = price("elec_light_install", 35.00)
        hardware = 15
        unit_cost = install + hardware
        material_list << {
          item:       "Light Fixture Install (labor + hardware)",
          quantity:   fixture_count,
          unit:       "each",
          unit_cost:  unit_cost,
          total_cost: fixture_count * unit_cost,
          category:   "Lighting"
        }
        total_labor_hours += fixture_count * (install / labor_rate)
      end

      if recessed_count > 0
        p = price("elec_recessed", 55.00)
        material_list << {
          item:       "Recessed Lights",
          quantity:   recessed_count,
          unit:       "each",
          unit_cost:  p,
          total_cost: recessed_count * p,
          category:   "Lighting"
        }
        total_labor_hours += recessed_count * 1.5
      end

      if circuits_20a > 0
        p = price("elec_circuit_20a", 95.00)
        material_list << {
          item:       "20A Dedicated Circuit",
          quantity:   circuits_20a,
          unit:       "each",
          unit_cost:  p,
          total_cost: circuits_20a * p,
          category:   "Circuits"
        }
        total_labor_hours += circuits_20a * 2.0
      end

      if circuits_30a > 0
        p = price("elec_circuit_30a", 130.00)
        material_list << {
          item:       "30A Dedicated Circuit",
          quantity:   circuits_30a,
          unit:       "each",
          unit_cost:  p,
          total_cost: circuits_30a * p,
          category:   "Circuits"
        }
        total_labor_hours += circuits_30a * 2.5
      end

      if circuits_50a > 0
        p = price("elec_circuit_50a", 185.00)
        material_list << {
          item:       "50A Dedicated Circuit",
          quantity:   circuits_50a,
          unit:       "each",
          unit_cost:  p,
          total_cost: circuits_50a * p,
          category:   "Circuits"
        }
        total_labor_hours += circuits_50a * 3.0
      end
    end

    if ev_charger == "yes"
      ev_price = price("elec_ev_charger", 350.00)
      ev_wire_run = 100
      unit_cost = ev_price + ev_wire_run
      material_list << {
        item:       "EV Charger Install + Wire Run",
        quantity:   1,
        unit:       "each",
        unit_cost:  unit_cost,
        total_cost: unit_cost,
        category:   "Specialty"
      }
      total_labor_hours += 4
    end

    # Legacy JS parity: permit included unless explicitly "no".
    permit_str = permit_val.to_s.downcase
    unless permit_str == "no"
      permit_price = price("elec_permit", 200.00)
      material_list << {
        item:       "Electrical Permit",
        quantity:   1,
        unit:       "each",
        unit_cost:  permit_price,
        total_cost: permit_price,
        category:   "Permit"
      }
    end

    material_list << {
      item:       "Equipment & Consumables",
      quantity:   1,
      unit:       "lot",
      unit_cost:  150,
      total_cost: 150,
      category:   "Equipment"
    }

    total_labor_hours *= complexity_multiplier
    total_labor_hours = 2 if total_labor_hours < 2

    labor_cost = total_labor_hours * labor_rate
    material_list << {
      item:       "Labor (#{home_age} home, #{stories}-story)",
      quantity:   (total_labor_hours * 100).round / 100.0,
      unit:       "hours",
      unit_cost:  labor_rate,
      total_cost: (labor_cost * 100).round / 100.0,
      category:   "Labor"
    }

    total_material_cost = material_list.reject { |i| i[:category] == "Labor" }
                                       .sum { |i| i[:total_cost] }

    {
      trade:                 "electrical",
      total_material_cost:   (total_material_cost * 100).round / 100.0,
      labor_hours:           (total_labor_hours * 10).round / 10.0,
      material_list:         material_list,
      complexity_multiplier: complexity_multiplier
    }
  end

  def truthy?(v)
    return false if v.nil?
    case v
    when true         then true
    when false        then false
    when Numeric      then v != 0
    when String       then %w[true yes 1 on].include?(v.downcase)
    else                   !!v
    end
  end
end
