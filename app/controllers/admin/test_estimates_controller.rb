module Admin
  class TestEstimatesController < ApplicationController
    layout false

    TRADES = %w[roofing plumbing drywall flooring painting siding hvac electrical].freeze
    DEFAULT_HOURLY_RATE = 65

    def index
      @trades      = TRADES
      @mode        = (params[:mode].presence_in(%w[single remodel]) || "single")
      @selected    = selected_trade
      @hourly_rate = parsed_hourly_rate
      @submitted   = request.post?
      @criteria    = criteria_for_form
      @results     = []
      @errors      = []

      return unless @submitted

      trades_to_run = @mode == "remodel" ? selected_remodel_trades : [@selected]

      if trades_to_run.empty?
        @errors << "Pick at least one trade to run."
        return
      end

      trades_to_run.each do |trade|
        criteria = @criteria[trade] || {}
        validation_errors = validate_criteria(trade, criteria)
        if validation_errors.any?
          @errors.concat(validation_errors.map { |msg| "#{trade.capitalize}: #{msg}" })
          @results << {
            trade:               trade,
            criteria:            criteria,
            material_list:       [],
            total_material_cost: 0,
            labor_hours:         0,
            labor_cost:          0,
            trade_total:         0,
            error:               validation_errors.join("; ")
          }
          next
        end
        @results << run_trade(trade, criteria)
      end
    end

    private

    # Required-positive fields per trade. squareFeet > 0 is a hard requirement
    # because the generator's math (sqrt, per-sqft multipliers) goes sideways
    # on zero/negative inputs. Other numeric fields just need to be >= 0.
    REQUIRED_POSITIVE_FIELDS = {
      "roofing"    => %w[squareFeet],
      "plumbing"   => %w[squareFeet],
      "drywall"    => %w[squareFeet],
      "flooring"   => %w[squareFeet],
      "painting"   => %w[squareFeet],
      "siding"     => %w[squareFeet],
      "hvac"       => %w[squareFeet],
      "electrical" => %w[squareFeet]
    }.freeze

    def validate_criteria(trade, criteria)
      errors = []
      fields = Admin::TestEstimatesHelper::TRADE_FIELDS[trade] || []
      required = REQUIRED_POSITIVE_FIELDS[trade] || []

      fields.each do |field|
        next unless field[:type] == :number
        name = field[:name].to_s
        raw  = criteria[name]
        raw  = raw.to_s.strip if raw.is_a?(String)

        if required.include?(name) && (raw.nil? || raw == "")
          errors << "#{field[:label]} is required."
          next
        end
        next if raw.nil? || raw == ""

        unless raw.to_s.match?(/\A-?\d+(\.\d+)?\z/)
          errors << "#{field[:label]} must be a number (got #{raw.inspect})."
          next
        end

        num = raw.to_s.include?(".") ? raw.to_f : raw.to_i
        if required.include?(name) && num <= 0
          errors << "#{field[:label]} must be greater than zero."
        elsif num.negative?
          errors << "#{field[:label]} cannot be negative."
        end
      end

      errors
    end

    def selected_trade
      requested = params[:trade].to_s.downcase
      TRADES.include?(requested) ? requested : TRADES.first
    end

    def parsed_hourly_rate
      raw = params[:hourly_rate]
      return DEFAULT_HOURLY_RATE if raw.blank?

      rate = raw.to_f
      rate.positive? ? rate : DEFAULT_HOURLY_RATE
    end

    def selected_remodel_trades
      Array(params[:remodel_trades]).map(&:to_s).map(&:downcase).select { |t| TRADES.include?(t) }
    end

    # params[:criteria] is a nested hash keyed by trade → {field => value}.
    # Preserve whatever the user posted so re-renders keep the form state.
    def criteria_for_form
      submitted = params[:criteria].respond_to?(:to_unsafe_h) ? params[:criteria].to_unsafe_h : (params[:criteria] || {})
      TRADES.each_with_object({}) do |trade, memo|
        memo[trade] = (submitted[trade] || {}).transform_keys(&:to_s)
      end
    end

    def run_trade(trade, raw_criteria)
      criteria = normalize_criteria(raw_criteria)
      result   = MaterialListGenerator.call(
        trade: trade,
        criteria: criteria,
        contractor_id: nil,
        hourly_rate: @hourly_rate
      )

      material_list       = Array(result[:material_list] || result["material_list"])
      total_material_cost = (result[:total_material_cost] || result["total_material_cost"] || 0).to_f
      labor_hours         = (result[:labor_hours] || result["labor_hours"] || 0).to_f
      labor_cost          = (result[:labor_cost] || result["labor_cost"] || (labor_hours * @hourly_rate)).to_f
      source_summary      = (result[:price_source_summary] || result["price_source_summary"] || {})

      {
        trade:                 trade,
        criteria:              criteria,
        material_list:         material_list,
        total_material_cost:   total_material_cost,
        labor_hours:           labor_hours,
        labor_cost:            labor_cost,
        trade_total:           total_material_cost + labor_cost,
        price_source_summary:  source_summary,
        error:                 nil
      }
    rescue MaterialListGenerator::UnsupportedTrade => e
      { trade: trade, error: e.message, material_list: [], total_material_cost: 0, labor_hours: 0, labor_cost: 0, trade_total: 0 }
    rescue => e
      Rails.logger.error("[TEA-236] test estimate crashed for #{trade}: #{e.class} #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
      { trade: trade, error: "Generator error — please check your inputs and try again.", material_list: [], total_material_cost: 0, labor_hours: 0, labor_cost: 0, trade_total: 0 }
    end

    # Coerce blank strings to nil so the service's own defaults apply, and
    # coerce numeric fields to numbers. Booleans come in as "1"/"0" from
    # checkboxes; keep them as truthy/falsy the service accepts.
    def normalize_criteria(raw)
      raw.each_with_object({}) do |(k, v), memo|
        next if v.is_a?(String) && v.strip.empty?

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
