require "pathname"

namespace :acceptance do
  desc "TEA-319: run the 3 acceptance scenarios (Denver kitchen, Phoenix bathroom, Charlotte addition) and emit line-by-line PASS/FAIL"
  task scenarios: :environment do
    require Rails.root.join("lib/acceptance/scenario").to_s
    require Rails.root.join("lib/acceptance/reporter").to_s

    fixtures_dir = Rails.root.join("test/acceptance/fixtures")
    fixtures = %w[denver_kitchen.yml phoenix_bathroom.yml charlotte_addition.yml]

    overall_pass = true
    fixtures.each do |fname|
      path = fixtures_dir.join(fname)
      scenario = Acceptance::Scenario.load(path)
      results, summary = scenario.run
      puts Acceptance::Reporter.new(scenario: scenario, results: results, summary: summary).call
      puts ""

      generator_fail = results.any? { |r| r.kind == :generator && r.status == :fail }
      grand_fail     = summary[:grand_status] == :fail
      overall_pass &&= !(generator_fail || grand_fail)
    end

    exit_code = overall_pass ? 0 : 1
    puts "==> TEA-319 acceptance: #{overall_pass ? 'ALL GREEN' : 'NOT GREEN — fix every FAIL before showing Johnny'}"
    exit(exit_code)
  end
end
