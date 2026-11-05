# frozen_string_literal: true

require_relative '../test_helper'

# Exercise the real native compiler with both successful and failing scenarios.
class CatalogParallelEquivalenceTest < Minitest::Test
  include CatalogTestSupport

  def test_native_reports_keep_selection_order_and_classification
    scenarios = [scenario('failure', "fail('synthetic compilation failure')"), scenario('success', "notify { 'ok': }")]
    reports = [1, 2, 4].map do |jobs|
      run_cases(scenarios, jobs)
    end
    assert_equal [reports.first], reports.uniq
    assert_equal %w[failure success], reports.first.map(&:first)
  end

  def run_cases(scenarios, jobs)
    runner = ProjectTools::Catalog.new(modulepath: @root, scenarios: scenarios, jobs: jobs,
                                       console: StringIO.new, errors: StringIO.new)
    assert_equal 1, runner.run(report: report_path)
    report_suite.get_elements('testcase').map { |test| [test.attributes['name'], test.elements.map(&:name)] }
  end
end
