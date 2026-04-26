require "yaml"

module Acceptance
  # Runs a TEA-319 acceptance scenario: loads a fixture (Denver kitchen,
  # Phoenix bathroom, Charlotte addition), drives MaterialListGenerator per
  # trade, and diffs the per-trade Material/Labor/Total rollups + grand total
  # against the truth-source CSVs Johnny built (attached to TEA-319).
  #
  # Two trade kinds:
  #   - :generator — has a MaterialListGenerator builder. Runner calls it,
  #                  collects total_material_cost + (labor_hours * hourly_rate),
  #                  diffs against expected.
  #   - :allowance — flat GC/admin/cleanup line. Runner echoes the expected
  #                  values; diff is trivially PASS. Marked "(allowance)" in
  #                  the report so it's clear what is and isn't generator-driven.
  #
  # A FAIL means the generator output does not match Johnny's truth-source.
  # Todd fixes the generator, the trade builder, the pricing snapshot, or the
  # fixture inputs until all rollups match.
  class Scenario
    Result = Struct.new(:trade_key, :label, :kind, :expected, :actual, :status, :reason,
                        :mode, :sentinel_ref, :csv_target, keyword_init: true)

    DEFAULT_TOLERANCE       = 5  # per-trade rollup tolerance, dollars
    DEFAULT_GRAND_TOLERANCE = 25 # grand-total tolerance, dollars (wider so per-trade rounding doesn't compound into a false FAIL)

    attr_reader :name, :type, :preset, :hourly_rate, :gc_pct, :contingency_pct,
                :tolerance, :grand_tolerance, :trades, :expected_grand_total

    def self.load(path)
      raw = YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true)
      new(raw, source: path)
    end

    def initialize(raw, source: nil)
      @source                = source
      @name                  = raw.fetch("name")
      @type                  = raw.fetch("type")
      @preset                = raw.fetch("preset")
      @hourly_rate           = raw.fetch("hourly_rate", 65).to_f
      @gc_pct                = raw.fetch("gc_pct", 0.10).to_f
      @contingency_pct       = raw.fetch("contingency_pct", 0.10).to_f
      @tolerance             = raw.fetch("tolerance", DEFAULT_TOLERANCE).to_f
      @grand_tolerance       = raw.fetch("grand_tolerance", DEFAULT_GRAND_TOLERANCE).to_f
      @trades                = raw.fetch("trades")
      @expected_grand_total  = raw.fetch("expected_grand_total").to_f
    end

    def run
      results = trades.map { |trade_def| run_trade(trade_def) }
      summary = build_summary(results)
      [results, summary]
    end

    private

    def run_trade(trade_def)
      key   = trade_def.fetch("key")
      label = trade_def.fetch("label")
      kind  = trade_def.fetch("kind").to_sym
      expected = symbolize(trade_def.fetch("expected"))
      mode         = trade_def["mode"]&.to_sym
      sentinel_ref = trade_def["sentinel_ref"]
      csv_target   = trade_def["csv_target"] ? symbolize(trade_def["csv_target"]) : nil

      if kind == :allowance
        note = trade_def["note"]
        reason = note ? "allowance — #{note}" : "allowance"
        return Result.new(
          trade_key: key, label: label, kind: kind,
          expected: expected, actual: expected.dup,
          status: :pass, reason: reason,
          mode: mode, sentinel_ref: sentinel_ref, csv_target: csv_target
        )
      end

      trade   = trade_def.fetch("trade")
      inputs  = (trade_def["inputs"] || {}).transform_keys(&:to_s)

      generator_result = MaterialListGenerator.call(
        trade:       trade,
        criteria:    inputs,
        hourly_rate: hourly_rate
      )

      material = generator_result[:total_material_cost].to_f.round
      labor    = (generator_result[:labor_hours].to_f * hourly_rate).round
      total    = material + labor
      actual   = { material: material, labor: labor, total: total }

      diff_status(key, label, kind, expected, actual, mode: mode, sentinel_ref: sentinel_ref, csv_target: csv_target)
    rescue MaterialListGenerator::UnsupportedTrade,
           MaterialListGenerator::InvalidCriteria => e
      Result.new(
        trade_key: key, label: label, kind: kind,
        expected: expected, actual: { material: 0, labor: 0, total: 0 },
        status: :fail, reason: "generator error: #{e.message}",
        mode: mode, sentinel_ref: sentinel_ref, csv_target: csv_target
      )
    end

    def diff_status(key, label, kind, expected, actual, mode: nil, sentinel_ref: nil, csv_target: nil)
      mat_delta   = (actual[:material] - expected[:material]).abs
      labor_delta = (actual[:labor]    - expected[:labor]).abs
      total_delta = (actual[:total]    - expected[:total]).abs

      mismatches = []
      mismatches << "material Δ$#{mat_delta}"   if mat_delta   > tolerance
      mismatches << "labor Δ$#{labor_delta}"    if labor_delta > tolerance
      mismatches << "total Δ$#{total_delta}"    if total_delta > tolerance

      status = mismatches.empty? ? :pass : :fail
      Result.new(
        trade_key: key, label: label, kind: kind,
        expected: expected, actual: actual,
        status: status, reason: mismatches.join(", "),
        mode: mode, sentinel_ref: sentinel_ref, csv_target: csv_target
      )
    end

    def build_summary(results)
      direct_material = results.sum { |r| r.actual[:material].to_i }
      direct_labor    = results.sum { |r| r.actual[:labor].to_i }
      direct_total    = direct_material + direct_labor
      overhead        = (direct_total * gc_pct).round
      contingency     = (direct_total * contingency_pct).round
      grand_total     = direct_total + overhead + contingency
      grand_delta     = (grand_total - expected_grand_total).abs
      grand_status    = grand_delta > grand_tolerance ? :fail : :pass

      {
        direct_material:      direct_material,
        direct_labor:         direct_labor,
        direct_total:         direct_total,
        gc_overhead:          overhead,
        contingency:          contingency,
        grand_total:          grand_total,
        expected_grand_total: expected_grand_total,
        grand_delta:          grand_delta,
        grand_status:         grand_status
      }
    end

    def symbolize(hash)
      hash.transform_keys(&:to_sym).transform_values { |v| v.is_a?(Numeric) ? v : v.to_f }
    end
  end
end
