# frozen_string_literal: true

require_relative 'catalog_support'

# Skips reach real consumers without suppressing independent catalog failures.
class CatalogConsumerSkipsTest < Minitest::Test
  include CatalogConsumerSupport

  def test_resource_validation_skips_reach_cli_and_rake_with_and_without_reports
    sample_guard_module
    %i[cli rake].each do |entry|
      invoke(entry, report: true)
      assert @status.success?, @output + @errors
      assert_skip_results
      assert_report_preserved(entry)
      assert_log_status('SKIPPED')
      assert_includes @output, 'Dependency cycle checks: 1 skipped'
    end
  end

  def test_an_independent_cycle_still_fails_both_consumer_entry_points
    sample_guard_module
    sample_cycle_module
    %i[cli rake].each do |entry|
      invoke(entry, report: true)
      assert_cycle_with_skip
    end
  end

  def assert_cycle_with_skip
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_log_status('FAILED')
    assert_counts(%w[3 1 0])
    assert_equal '1', suite.attributes['skipped']
    assert_equal 'DependencyCycle', suite.elements['testcase/failure'].attributes['type']
  end

  def sample_guard_module
    sample_module('global-modules', 'guard_probe', body: <<~PUPPET)
      exec { 'guard': command => '/usr/bin/true', onlyif => '[ -e /synthetic/missing ]' }
    PUPPET
  end

  def assert_skip_results
    assert_log_status('SKIPPED')
    assert_counts(%w[2 0 0])
    assert_equal '1', suite.attributes['skipped']
    pattern = %r{Dependency cycle check skipped.*Affected \(1 scenario\):\n    - guard_probe/default \[synthetic\]}m
    assert_match(pattern, @output)
    assert_includes @output, '2 selected | 2 processed | 1 checked'
    assert_includes @output, 'Execution: incomplete'
    assert_skip_case
    assert suite.get_elements('testcase').last.elements['system-out']
  end

  def assert_skip_case
    item = suite.get_elements('testcase').first
    assert_nil item.elements['system-out']
    assert_includes item.elements['skipped'].text, 'Cycle freedom was not checked.'
    assert_equal 1, @output.scan("'[' is not qualified").size
  end
end
