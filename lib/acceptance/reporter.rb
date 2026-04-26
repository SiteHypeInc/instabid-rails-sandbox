module Acceptance
  # Renders a scenario run as the line-by-line PASS/FAIL report from the
  # TEA-318 founder directive: ✅ / ❌ per trade, then per-trade Material /
  # Labor / Total totals, then Grand Total. Green-only delivery: caller is
  # responsible for not shipping a partial report to Johnny.
  class Reporter
    PASS = "✅"
    FAIL = "❌"

    def initialize(scenario:, results:, summary:)
      @scenario = scenario
      @results  = results
      @summary  = summary
    end

    def call
      lines = []
      lines << "## #{@scenario.name}"
      lines << "Type: #{@scenario.type} / preset: #{@scenario.preset} / hourly rate: $#{@scenario.hourly_rate.to_i}"
      lines << ""
      @results.each { |r| lines.concat(format_trade(r)) }
      lines << ""
      lines.concat(format_summary)
      lines << ""
      lines << overall_line
      lines.join("\n")
    end

    private

    def format_trade(result)
      icon  = result.status == :pass ? PASS : FAIL
      kind_tag = if result.kind == :allowance
        " (allowance)"
      elsif result.mode == :sentinel
        " [sentinel: #{result.sentinel_ref || 'TEA-323'}]"
      elsif result.mode == :"csv-match" || result.mode == :csv_match
        " [csv-match]"
      else
        ""
      end
      exp   = result.expected
      act   = result.actual
      head  = "#{icon} #{result.label}#{kind_tag}"
      detail = +""
      detail << "expected M=$#{exp[:material].to_i} L=$#{exp[:labor].to_i} T=$#{exp[:total].to_i}"
      detail << " — got M=$#{act[:material].to_i} L=$#{act[:labor].to_i} T=$#{act[:total].to_i}"
      detail << " — #{result.status.to_s.upcase}"
      if !result.reason.to_s.empty? && result.reason != "allowance"
        detail << " (#{result.reason})"
      end
      lines = ["#{head}: #{detail}"]
      if result.mode == :sentinel && result.csv_target
        ct = result.csv_target
        lines << "    ↳ csv_target M=$#{ct[:material].to_i} L=$#{ct[:labor].to_i} T=$#{ct[:total].to_i} — disclosure only, builder gap tracked in #{result.sentinel_ref || 'TEA-323'}"
      end
      lines
    end

    def format_summary
      s = @summary
      sentinel_count = @results.count { |r| r.kind == :generator && r.status == :pass && r.mode == :sentinel }
      absorbs = sentinel_count.positive? ? " [absorbs #{sentinel_count} sentinel#{'s' if sentinel_count != 1}]" : ""
      [
        "──────────────────────────────────────────────",
        "Direct Material : $#{s[:direct_material]}",
        "Direct Labor    : $#{s[:direct_labor]}",
        "Direct Total    : $#{s[:direct_total]}",
        "GC Overhead     : $#{s[:gc_overhead]} (#{(@scenario.gc_pct * 100).round(1)}%)",
        "Contingency     : $#{s[:contingency]} (#{(@scenario.contingency_pct * 100).round(1)}%)",
        "──────────────────────────────────────────────",
        "Grand Total     : $#{s[:grand_total]} (expected $#{s[:expected_grand_total].to_i}, Δ$#{s[:grand_delta].to_i})#{absorbs}",
      ]
    end

    def overall_line
      total      = @results.size
      generator  = @results.count { |r| r.kind == :generator }
      passed_gen = @results.count { |r| r.kind == :generator && r.status == :pass }
      failed_gen = generator - passed_gen
      csv_match  = @results.count { |r| r.kind == :generator && r.status == :pass && (r.mode == :"csv-match" || r.mode == :csv_match) }
      sentinel   = @results.count { |r| r.kind == :generator && r.status == :pass && r.mode == :sentinel }
      grand_pass = @summary[:grand_status] == :pass
      icon       = (failed_gen.zero? && grand_pass) ? PASS : FAIL
      breakdown  = generator.positive? ? " (#{csv_match} csv-match, #{sentinel} sentinel)" : ""
      "#{icon} Scenario: #{passed_gen}/#{generator} generator-trades pass#{breakdown}; grand-total #{grand_pass ? 'PASS' : 'FAIL'}; #{total} total trades"
    end
  end
end
