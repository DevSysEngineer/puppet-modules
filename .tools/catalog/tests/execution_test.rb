# frozen_string_literal: true

require_relative 'test_helper'

# Controlled events exercise progress and interruption without depending on scheduling.
class CatalogExecutionTest < Minitest::Test
  include CatalogTestSupport

  def test_missing_or_malformed_deprecation_results_are_execution_errors
    runner = catalog_runner([])
    status = Struct.new(:exitstatus).new(0)
    ['{}', '[]', '{"deprecations":null}', '{"deprecations":[{}]}',
     '{"deprecations":[{"message":3}]}', '{"deprecations":[],"deprecation_error":false}'].each do |output|
      result = runner.worker_result({ name: 'synthetic' }, output, 'native diagnostic', status)
      assert_equal :error, result[:kind], output
      assert_includes result[:message], 'Invalid compiler result'
      assert_includes result[:message], 'native diagnostic'
    end
  end

  def test_successful_worker_with_deprecations_is_a_quality_failure
    runner = catalog_runner([])
    status = Struct.new(:exitstatus).new(0)
    output = JSON.generate(resources: 42, dependency_cycles: 0, deprecations: [{ message: 'synthetic deprecation' }])
    result = runner.worker_result({ name: 'synthetic' }, output, '', status)
    assert_equal :failure, result[:kind]
    assert_equal :deprecation, result[:cause]
    assert_equal 42, result[:resources]
  end

  def test_missing_or_invalid_cycle_results_cannot_pass
    runner = catalog_runner([])
    status = Struct.new(:exitstatus).new(0)
    [{}, { dependency_cycles: nil }, { dependency_cycles: -1 }, { dependency_cycles: false }].each do |details|
      output = JSON.generate(details.merge(deprecations: []))
      result = runner.worker_result({ name: 'synthetic' }, output, 'native diagnostic', status)
      assert_equal :error, result[:kind]
      assert_includes result[:message], 'missing or invalid dependency cycle check'
      assert_includes result[:message], 'native diagnostic'
    end
  end

  def test_progress_uses_shared_format_and_counts_completed_scenarios
    runner = catalog_runner([scenario('first', ''), scenario('second', '')])
    runner.define_singleton_method(:compile) do |input|
      @console.progress
      { name: input[:name], kind: nil, message: '', resources: 2 }
    end
    assert_equal 0, runner.run
    assert_match(/\[PROGRESS\] Puppet catalogs \| Still running \| \d+ s \| no new results/, @console.string)
    assert_match(%r{\[PROGRESS\] Puppet catalogs \| 1/2 scenarios processed \| \d+ s}, @console.string)
    assert_includes @console.string, '2 selected | 2 processed | 2 checked'
    assert_primary_status('PASSED')
  end

  def test_interruption_keeps_completed_results_and_has_one_incomplete_status
    runner = catalog_runner([scenario('first', ''), scenario('interrupted', '')])
    runner.define_singleton_method(:compile) do |input|
      raise Interrupt if input[:name] == 'interrupted'

      { name: input[:name], kind: :failure, message: 'earlier compilation failure' }
    end
    assert_raises(Interrupt) { runner.run }
    assert_interrupted_result
  end

  def assert_interrupted_result
    assert_primary_status('ERROR')
    assert_includes @console.string, 'Execution: incomplete'
    assert_includes @console.string, '2 selected | 1 processed | 1 checked'
    assert_occurs_once('earlier compilation failure')
    refute_includes @console.string, 'JUnit written:'
  end

  def test_identical_execution_errors_are_grouped_only_in_the_final_block
    output = @console
    runner = catalog_runner([scenario('second', ''), scenario('first', '')])
    runner.define_singleton_method(:compile) do |input|
      raise 'diagnostic printed during execution' if output.string.include?('synthetic cause')

      { name: input[:name], kind: :error, message: "synthetic cause\nfull last line" }
    end
    assert_equal 1, runner.run(report: report_path)
    assert_grouped_errors
    assert_equal 2, report_suite.get_elements('testcase/error').size
  end

  def assert_grouped_errors
    assert_primary_status('ERROR')
    assert_includes @console.string, '2 selected | 2 processed | 0 checked'
    assert_occurs_once('synthetic cause')
    assert_includes @console.string, "  full last line\n  Affected:\n    - first\n    - second"
    assert_operator @console.string.index('[ERROR]'), :<, @console.string.index('synthetic cause')
  end
end
