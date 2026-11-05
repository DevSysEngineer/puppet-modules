# frozen_string_literal: true

require_relative 'test_helper'

# A skip needs an explicit reason and must never override another validation error.
class CatalogDependencyCycleProtocolTest < Minitest::Test
  include CatalogCycleTestSupport

  def test_missing_invalid_or_conflicting_skip_results_are_errors
    details = [nil, '', ' ', false, 1, {}].map { |reason| { dependency_cycle_skip: reason } }
    details << { dependency_cycle_skip: 'native resource validation', dependency_cycles: 0 }
    details.each do |entry|
      result = worker_result(entry)
      assert_equal :error, result[:kind]
      assert_includes result[:message], 'missing or invalid dependency cycle check'
    end
  end

  def test_incomplete_deprecation_validation_takes_precedence_over_skip
    result = worker_result(dependency_cycle_skip: 'native resource validation', deprecation_error: 'synthetic error')
    assert_equal :error, result[:kind]
    assert_equal 'native resource validation', result[:dependency_cycle_skip]
  end

  def test_resource_error_from_the_cycle_reporter_is_not_an_environment_skip
    input = scenario('broken reporter', <<~PUPPET)
      inline_template('<% Puppet::Graph::SimpleGraph.class_eval do
        def report_cycles_in_graph; raise Puppet::ResourceError, "synthetic reporter defect"; end
      end %>')
    PUPPET
    assert_equal 1, run_catalogs([input], report: report_path)
    assert_counts(%w[1 0 1])
    assert_equal '0', report_suite.attributes['skipped']
    assert_includes report_suite.elements['testcase/error'].text, 'Dependency cycle check could not run:'
    assert_occurs_once('synthetic reporter defect')
  end

  def worker_result(details)
    output = JSON.generate(details.merge(deprecations: []))
    ProjectTools::Catalog::WorkerResult.new('synthetic', output, '', Struct.new(:exitstatus).new(0)).result
  end
end
