# frozen_string_literal: true

require_relative 'test_helper'

# Native API faults stay distinct from configuration cycles and compiler failures.
class CatalogDependencyCycleErrorsTest < Minitest::Test
  include CatalogCycleTestSupport

  def test_native_graph_errors_and_missing_or_incompatible_interfaces_are_errors
    inputs = unavailable_scenarios
    inputs << scenario('later valid', "notify { 'valid': }")
    assert_equal 1, run_catalogs(inputs, report: report_path)
    assert_unavailable_results
  end

  def unavailable_scenarios
    mutations = [
      'Puppet::Resource::Catalog.class_eval { def to_ral; raise Puppet::Error, "synthetic graph error"; end }',
      'Puppet::Resource::Catalog.class_eval { undef_method :to_ral }',
      'Puppet::Graph::SimpleGraph.class_eval { undef_method :report_cycles_in_graph }',
      'Puppet::Graph::SimpleGraph.class_eval { def report_cycles_in_graph; []; end }'
    ]
    mutations.each_with_index.map do |code, index|
      scenario("unavailable #{index}", "inline_template('<% #{code} %>')")
    end
  end

  def assert_unavailable_results
    assert_counts(%w[5 0 4])
    assert_primary_status('ERROR')
    assert_includes @console.string, 'Execution: incomplete'
    assert_includes @console.string, '5 selected | 1 checked'
    assert_occurs_once('Puppet::Error: synthetic graph error')
    report_suite.get_elements('testcase/error').each do |error|
      assert_equal 'CompilerError', error.attributes['type']
      assert_includes error.text, 'Dependency cycle check could not run:'
    end
  end

  def test_cycle_remains_primary_with_deprecations_and_independent_compilation_failure
    prepare_mixed_failures
    assert_equal 1, run_catalogs(nil, report: report_path)
    assert_counts(%w[2 2 0])
    assert_mixed_failures
    ['synthetic cycle deprecation', 'synthetic compile failure'].each { |message| assert_occurs_once(message) }
  end

  def assert_mixed_failures
    types = report_suite.get_elements('testcase/failure').map { |failure| failure.attributes['type'] }
    assert_equal %w[DependencyCycle CatalogFailure], types
    assert_includes report_suite.elements['testcase/failure'].text, 'Native deprecations: 1'
  end

  def prepare_mixed_failures
    directory = prepare_cycle_module
    File.write(File.join(directory, 'tests/manifests/default.pp'), <<~PUPPET)
      inline_template('<% Puppet.deprecation_warning("synthetic cycle deprecation", "cycle") %>')
      include cycle_probe
    PUPPET
    File.write(File.join(directory, 'tests/manifests/invalid.pp'), "fail('synthetic compile failure')")
  end
end
