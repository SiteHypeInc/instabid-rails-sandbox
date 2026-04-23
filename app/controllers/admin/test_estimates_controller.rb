module Admin
  class TestEstimatesController < ApplicationController
    include Admin::TestEstimatesHelper

    layout false

    TRADES = %w[roofing plumbing drywall flooring painting siding hvac electrical].freeze
    DEFAULT_HOURLY_RATE = 65
    VALID_MODES = %w[single remodel].freeze

    def index
      @trades          = TRADES
      @mode            = (params[:mode].presence_in(VALID_MODES) || "single")
      @selected        = selected_trade
      @hourly_rate     = parsed_hourly_rate
      @submitted       = request.post?
      @criteria        = criteria_for_form
      @remodel_type    = (params[:remodel_type].presence_in(REMODEL_TYPES) || "kitchen")
      @remodel_preset  = selected_remodel_preset(@remodel_type)
      @remodel_input   = remodel_input_for_form
      @results         = []
      @remodel_summary = nil
      @input_errors    = []

      return unless @submitted

      validate_inputs!

      if @input_errors.any?
        # Halt before hitting the generator — bad input should never render a
        # plausible-looking $0 estimate (TEA-234 smoke item #1).
        return
      end

      if @mode == "remodel"
        @results, @remodel_summary = run_remodel(@remodel_type, @remodel_preset, @remodel_input)
      else
        criteria = @criteria[@selected] || {}
        @results << run_trade(@selected, criteria)
      end
    end

    private

    # Reject non-positive / non-numeric sqft inputs before they reach the
    # generator. TEA-234 smoke items #1 + guard against Math::DomainError on
    # negative sqrt in roofing/plumbing/etc.
    CRITICAL_SQFT_FIELDS = %w[squareFeet square_feet kitchen_sqft bathroom_sqft addition_sqft floor_tile_sqft flooring_sqft backsplash_sqft counter_sqft].freeze

    def validate_inputs!
      errors = []
      if @mode == "single"
        posted = @criteria[@selected] || {}
        posted.each do |k, v|
          msg = sqft_error(@selected, k, v)
          errors << msg if msg
        end
      else
        (@remodel_input[@remodel_type] || {}).each do |_section, fields|
          (fields || {}).each do |k, v|
            msg = sqft_error("remodel:#{@remodel_type}", k, v)
            errors << msg if msg
          end
        end
      end
      @input_errors = errors
    end

    def sqft_error(scope, key, raw)
      return nil unless CRITICAL_SQFT_FIELDS.include?(key.to_s)
      return nil if raw.nil? || raw.to_s.strip.empty?
      return "#{scope} / #{key} must be a number (got #{raw.inspect})" unless raw.to_s.match?(/\A-?\d+(\.\d+)?\z/)

      numeric = raw.to_f
      if numeric < 0
        "#{scope} / #{key} cannot be negative (got #{raw})"
      elsif numeric.zero? && critical_sqft_required?(scope, key)
        "#{scope} / #{key} must be greater than zero"
      end
    end

    # Zero is only meaningful for the primary dimension of a trade — every
    # other "count" field is legitimately zero (no fixtures, no windows, etc.).
    def critical_sqft_required?(scope, key)
      return true if %w[squareFeet square_feet].include?(key.to_s) && TRADES.include?(scope.to_s)

      case scope
      when "remodel:kitchen"  then key.to_s == "kitchen_sqft"
      when "remodel:bathroom" then key.to_s == "bathroom_sqft"
      when "remodel:addition" then key.to_s == "addition_sqft"
      else false
      end
    end

    def selected_trade
      requested = params[:trade].to_s.downcase
      TRADES.include?(requested) ? requested : TRADES.first
    end

    def selected_remodel_preset(type)
      valid = REMODEL_PRESETS[type].map { |p| p[:value] }
      requested = params[:remodel_preset].to_s
      valid.include?(requested) ? requested : valid.first
    end

    def parsed_hourly_rate
      raw = params[:hourly_rate]
      return DEFAULT_HOURLY_RATE if raw.blank?

      rate = raw.to_f
      rate.positive? ? rate : DEFAULT_HOURLY_RATE
    end

    def criteria_for_form
      submitted = params[:criteria].respond_to?(:to_unsafe_h) ? params[:criteria].to_unsafe_h : (params[:criteria] || {})
      TRADES.each_with_object({}) do |trade, memo|
        memo[trade] = (submitted[trade] || {}).transform_keys(&:to_s)
      end
    end

    # params[:remodel] is shaped as remodel[<type>][<section_key>][<field>] so
    # each type keeps its own posted state across re-renders.
    def remodel_input_for_form
      raw = params[:remodel].respond_to?(:to_unsafe_h) ? params[:remodel].to_unsafe_h : (params[:remodel] || {})
      REMODEL_TYPES.each_with_object({}) do |type, memo|
        type_hash = (raw[type] || {}).each_with_object({}) do |(section_key, section_vals), acc|
          acc[section_key.to_s] = (section_vals || {}).transform_keys(&:to_s)
        end
        memo[type] = type_hash
      end
    end

    def run_trade(trade, raw_criteria)
      criteria = normalize_criteria(raw_criteria)
      invoke_generator(trade, criteria)
    end

    def invoke_generator(trade, criteria)
      result = MaterialListGenerator.call(
        trade: trade,
        criteria: criteria,
        contractor_id: nil,
        hourly_rate: @hourly_rate
      )

      material_list       = Array(result[:material_list] || result["material_list"])
      total_material_cost = (result[:total_material_cost] || result["total_material_cost"] || 0).to_f
      labor_hours         = (result[:labor_hours] || result["labor_hours"] || 0).to_f
      labor_cost          = (result[:labor_cost] || result["labor_cost"] || (labor_hours * @hourly_rate)).to_f

      {
        trade:                 trade,
        criteria:              criteria,
        material_list:         material_list,
        total_material_cost:   total_material_cost,
        labor_hours:           labor_hours,
        labor_cost:            labor_cost,
        trade_total:           total_material_cost + labor_cost,
        price_source_summary:  tally_price_sources(material_list),
        error:                 nil,
        unported:              false,
        package:               nil,
        package_label:         nil
      }
    rescue MaterialListGenerator::UnsupportedTrade => e
      blank_result(trade, error: e.message)
    rescue MaterialListGenerator::InvalidCriteria => e
      blank_result(trade, error: "Invalid input: #{e.message}")
    rescue => e
      Rails.logger.error("[TEA-239] test estimate crashed for #{trade}: #{e.class} #{e.message}")
      blank_result(trade, error: "#{e.class}: #{e.message}")
    end

    def blank_result(trade, error: nil, unported: false, package: nil)
      {
        trade:                 trade,
        criteria:              {},
        material_list:         [],
        total_material_cost:   0,
        labor_hours:           0,
        labor_cost:            0,
        trade_total:           0,
        price_source_summary:  {},
        error:                 error,
        unported:              unported,
        package:               package,
        package_label:         package ? REMODEL_PACKAGE_LABELS[package] : nil
      }
    end

    # MaterialListGenerator stamps :source on every line via PricingResolver's
    # dominant-source tracking. Tally it per-trade so the view can surface a
    # "Price Sources: HD Live (12), Manual (3)" strip. Labor rows have no
    # meaningful source, so drop them from the count.
    def tally_price_sources(material_list)
      material_list
        .reject { |line| (line[:category] || line["category"]).to_s == "Labor" }
        .group_by { |line| (line[:source] || line["source"] || "Manual").to_s }
        .transform_values(&:size)
        .sort_by { |_src, n| -n }
        .to_h
    end

    def run_remodel(type, preset, remodel_input)
      packages = remodel_packages_for(type, preset)
      flat_remodel = flatten_remodel(remodel_input[type] || {})
      results = packages.map { |pkg| run_remodel_package(type, pkg, flat_remodel) }

      direct_material = results.sum { |r| r[:total_material_cost].to_f }
      direct_labor    = results.sum { |r| r[:labor_cost].to_f }
      direct_total    = direct_material + direct_labor

      gc_pct    = gc_pct_for(type, preset)
      overhead  = direct_total * gc_pct
      contingency = direct_total * 0.10
      grand_total = direct_total + overhead + contingency

      summary = {
        type:            type,
        preset:          preset,
        direct_material: direct_material,
        direct_labor:    direct_labor,
        direct_total:    direct_total,
        gc_pct:          gc_pct,
        gc_overhead:     overhead,
        contingency:     contingency,
        grand_total:     grand_total
      }

      [results, summary]
    end

    def flatten_remodel(type_hash)
      type_hash.each_with_object({}) do |(_section_key, fields), memo|
        (fields || {}).each { |k, v| memo[k.to_s] = v }
      end
    end

    def gc_pct_for(type, preset)
      case [type, preset]
      when %w[kitchen cosmetic]      then 0.05
      when %w[kitchen pull_replace]  then 0.08
      when %w[kitchen full_gut]      then 0.10
      when %w[kitchen full_reconfig] then 0.12
      when %w[bathroom cosmetic]     then 0.05
      when %w[bathroom standard]     then 0.08
      when %w[bathroom shower_gut]   then 0.10
      when %w[bathroom spa_premium]  then 0.12
      else 0.10
      end
    end

    def run_remodel_package(type, package, flat_remodel)
      trade = REMODEL_PACKAGE_TO_TRADE[package]
      return blank_result(trade || package, unported: true, package: package) if trade.nil?

      criteria = build_trade_criteria(type, package, flat_remodel)
      result   = invoke_generator(trade, normalize_criteria(criteria))
      result[:package]       = package
      result[:package_label] = REMODEL_PACKAGE_LABELS[package]
      result
    end

    # Project-basics-independent derivation of MaterialListGenerator criteria
    # from the flat remodel form state. Only set keys we have real values for;
    # the service's own defaults cover the rest.
    def build_trade_criteria(type, package, f)
      case [type, package]
      when %w[kitchen flooring]
        {
          squareFeet:     f["kitchen_sqft"],
          flooringType:   map_flooring(f["flooring_material"]),
          removal:        bool_yn(f["floor_removal"]),
          subfloorRepair: bool_yn(f["subfloor_repair"] != "none"),
          complexity:     "standard"
        }
      when %w[kitchen painting]
        { squareFeet: f["kitchen_sqft"], paintType: "interior", coats: 2,
          includeCeilings: bool_yn(f["ceiling_paint"]), wallCondition: "smooth", patchingNeeded: "minor" }
      when %w[kitchen drywall]
        { squareFeet: f["kitchen_sqft"].to_f * 2.5, projectType: "remodel", rooms: 1,
          ceilingHeight: "8ft", finishLevel: "level_4_smooth", damageExtent: "moderate" }
      when %w[kitchen plumbing_rough], %w[kitchen plumbing_finish]
        {
          serviceType:       (package == "plumbing_rough" ? "rough_in" : "fixture_swap"),
          squareFeet:        f["kitchen_sqft"],
          bathrooms:         0,
          kitchens:          1,
          stories:           1,
          dishwasherHookup:  bool_yn(f["dishwasher_hookup"]),
          iceMaker:          bool_yn(f["ice_maker_line"]),
          garbageDisposal:   bool_yn(f["garbage_disposal"]),
          gasLineNeeded:     bool_yn(f["range_type"] == "gas"),
          sinkCount:         1,
          faucetCount:       1
        }
      when %w[kitchen electrical_rough], %w[kitchen electrical_finish], %w[kitchen electrical]
        circuits50 = f["range_type"] == "induction" ? 1 : 0
        {
          serviceType:     (package == "electrical_rough" ? "rewire" : "circuits"),
          squareFeet:      f["kitchen_sqft"],
          amperage:        (f["panel_upgrade"] == "main_200" ? "200" : "200"),
          stories:         1,
          gfciCount:       f["gfci_outlets"],
          outletCount:     f["gfci_outlets"],
          fixtureCount:    f["pendant_lights"],
          recessedCount:   f["recessed_lights"],
          ceilingFanCount: 0,
          circuits20a:     2,
          circuits50a:     circuits50
        }
      when %w[kitchen hvac]
        ductwork = f["hvac_changes"].to_s.in?(%w[duct_mod full_reroute]) ? "new" : "existing"
        { squareFeet: f["kitchen_sqft"], systemType: "furnace", efficiency: "standard", ductwork: ductwork }

      when %w[bathroom painting]
        { squareFeet: f["bathroom_sqft"], paintType: "interior", coats: 2,
          includeCeilings: bool_yn(f["ceiling_paint"]), wallCondition: "smooth" }
      when %w[bathroom drywall]
        { squareFeet: f["bathroom_sqft"].to_f * 2.5, projectType: "remodel", rooms: 1,
          ceilingHeight: "8ft", finishLevel: "level_4_smooth", damageExtent: "moderate" }
      when %w[bathroom plumbing_rough], %w[bathroom plumbing_finish]
        tub_shower = (f["bathing_type"].to_s != "keep") ? 1 : 0
        {
          serviceType:    (package == "plumbing_rough" ? "rough_in" : "fixture_swap"),
          squareFeet:     f["bathroom_sqft"],
          bathrooms:      1,
          kitchens:       0,
          stories:        1,
          toiletCount:    1,
          sinkCount:      (f["vanity_width"].to_i >= 60 ? 2 : 1),
          faucetCount:    (f["vanity_width"].to_i >= 60 ? 2 : 1),
          tubShowerCount: tub_shower
        }
      when %w[bathroom electrical]
        {
          serviceType:   "circuits",
          squareFeet:    f["bathroom_sqft"],
          amperage:      "200",
          stories:       1,
          gfciCount:     f["gfci_outlets"],
          outletCount:   f["gfci_outlets"],
          fixtureCount:  f["vanity_lighting"],
          recessedCount: f["recessed_lights"]
        }
      when %w[bathroom ventilation]
        { squareFeet: f["bathroom_sqft"], systemType: "furnace", efficiency: "standard", ductwork: "new" }
      when %w[bathroom flooring]
        if f["floor_tile_material"].to_s == "lvp"
          { squareFeet: f["floor_tile_sqft"] || f["bathroom_sqft"], flooringType: "lvp",
            removal: "yes", subfloorRepair: "no", complexity: "standard" }
        else
          # tile flooring isn't cleanly handled by flooring builder; let the
          # tile package handle it. Stub a minimal call here just to flag it.
          { squareFeet: f["floor_tile_sqft"] || f["bathroom_sqft"], flooringType: "ceramic_tile",
            removal: "yes", complexity: "complex" }
        end

      when %w[addition roofing]
        { squareFeet: f["addition_sqft"], pitch: "6/12", material: "architectural",
          layers: 1, existingRoofType: "asphalt" }
      when %w[addition siding]
        { squareFeet: f["addition_sqft"], sidingType: map_siding(f["exterior_finish"]),
          stories: (f["stories"] == "two" ? 2 : 1), needsRemoval: "no",
          windowCount: f["windows"], doorCount: f["exterior_doors"] }
      when %w[addition drywall]
        ceiling = f["ceiling_height"].to_s
        ceiling = "8ft" unless %w[8ft 9ft 10ft 12ft].include?(ceiling)
        { squareFeet: f["addition_sqft"].to_f * 3.0, projectType: "new_construction", rooms: 1,
          ceilingHeight: ceiling, finishLevel: "level_4_smooth" }
      when %w[addition flooring]
        { squareFeet: f["addition_sqft"], flooringType: map_flooring(f["flooring_material"]),
          removal: "no", subfloorRepair: "no", complexity: "standard" }
      when %w[addition painting]
        { squareFeet: f["addition_sqft"], paintType: "interior", coats: 2,
          includeCeilings: "yes", wallCondition: "smooth" }
      when %w[addition electrical]
        {
          serviceType:     "general",
          squareFeet:      f["addition_sqft"],
          amperage:        "200",
          stories:         (f["stories"] == "two" ? 2 : 1),
          recessedCount:   f["recessed_lights"],
          ceilingFanCount: (bool_yn(f["ceiling_fan"]) == "yes" ? 1 : 0),
          fixtureCount:    2,
          outletCount:     [f["addition_sqft"].to_i / 80, 4].max,
          gfciCount:       1
        }
      when %w[addition hvac]
        sys = case f["hvac_scope"].to_s
              when "mini_split" then "minisplit"
              when "none"       then "furnace"
              else "furnace"
              end
        { squareFeet: f["addition_sqft"], systemType: sys, ductwork: "new",
          stories: (f["stories"] == "two" ? 2 : 1) }
      when %w[addition plumbing_rough], %w[addition plumbing_finish]
        {
          serviceType: (package == "plumbing_rough" ? "rough_in" : "fixture_swap"),
          squareFeet:  f["addition_sqft"],
          bathrooms:   (f["wet_room_type"].to_s.match?(/bath/) ? 1 : 0),
          kitchens:    (f["wet_room_type"].to_s == "kitchenette" ? 1 : 0),
          laundryRooms:(f["wet_room_type"].to_s == "laundry" ? 1 : 0),
          stories:     (f["stories"] == "two" ? 2 : 1)
        }
      else
        {}
      end
    end

    def map_flooring(mat)
      case mat.to_s
      when "lvp"        then "lvp"
      when "tile"       then "porcelain_tile"
      when "hardwood"   then "engineered_hardwood"
      when "laminate"   then "laminate"
      when "carpet"     then "carpet"
      when "keep"       then "lvp" # nothing new installed; builder still needs a type
      else "lvp"
      end
    end

    def map_siding(finish)
      case finish.to_s
      when "vinyl"        then "vinyl"
      when "fiber_cement" then "fiber_cement"
      when "wood"         then "wood"
      when "stucco"       then "stucco"
      else "vinyl"
      end
    end

    def bool_yn(v)
      return v if v == "yes" || v == "no"
      return "yes" if v == true || v.to_s == "true" || v.to_s == "1"

      "no"
    end

    def normalize_criteria(raw)
      raw.each_with_object({}) do |(k, v), memo|
        next if v.nil? || (v.is_a?(String) && v.strip.empty?)

        memo[k.to_s] = if v.is_a?(String) && v.match?(/\A-?\d+(\.\d+)?\z/)
                         v.include?(".") ? v.to_f : v.to_i
                       elsif v == "true" || v == "1"
                         true
                       elsif v == "false" || v == "0"
                         false
                       else
                         v
                       end
      end
    end
  end
end
