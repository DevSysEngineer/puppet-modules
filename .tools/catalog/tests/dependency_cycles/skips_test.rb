# frozen_string_literal: true

require_relative 'test_helper'

# Native resource validation can prevent graph construction without proving a cycle.
class CatalogDependencyCycleSkipsTest < Minitest::Test
  include CatalogCycleTestSupport

  def test_guard_context_skips_one_graph_and_preserves_compilation_coverage_and_later_success
    prepare_guard_module
    assert_equal 0, run_catalogs(nil, report: report_path)
    assert_skip_summary
    assert_skipped_case
    assert_later_success
  end

  def assert_skip_summary
    assert_counts(%w[2 0 0])
    assert_equal '1', report_suite.attributes['skipped']
    assert_primary_status('SKIPPED')
    assert_includes @console.string, 'Execution: incomplete'
    assert_includes @console.string, '2 selected | 2 processed | 1 checked'
    assert_match(%r{Dependency cycle check skipped.*Affected:\n    - guard_probe/default \[debian\]}m, @console.string)
    assert_occurs_once("'[' is not qualified")
  end

  def test_all_skips_succeed_without_junit_and_preserve_an_existing_report
    report = stale_report
    assert_equal 0, run_catalogs([scenario('guard [synthetic]', guard_resource)])
    assert_primary_status('SKIPPED')
    assert_includes @console.string, 'Dependency cycle checks: 1 skipped'
    assert_includes @console.string, '1 selected | 1 processed | 0 checked'
    assert_equal '<previous/>', File.read(report)
    refute_includes @console.string, 'JUnit written:'
  end

  def test_missing_provider_feature_skips_native_graph_construction
    input = scenario('provider [synthetic]', <<~PUPPET)
      inline_template('<% Puppet::Type.type(:package).provide(:catalog_without_purge) {} %>')
      package { 'synthetic': ensure => purged, provider => catalog_without_purge }
    PUPPET
    assert_equal 0, run_catalogs([input], report: report_path)
    assert_equal '1', report_suite.attributes['skipped']
    assert_includes report_suite.elements['testcase/skipped'].text, "must have features 'purgeable'"
  end

  def test_a_skipped_graph_does_not_hide_an_independent_cycle_or_claim_cycle_freedom
    prepare_cycle_module
    module_inputs('unavailable', code: guard_resource)
    assert_equal 1, run_catalogs(nil, report: report_path)
    assert_counts(%w[2 1 0])
    assert_equal '1', report_suite.attributes['skipped']
    assert_primary_status('FAILED')
    assert_includes report_suite.elements['testcase/skipped'].text, 'Cycle freedom was not checked.'
  end

  def test_deprecations_still_fail_when_resource_validation_skips_the_cycle_check
    code = "inline_template('<% Puppet.deprecation_warning(\"synthetic skip deprecation\", \"skip\") %>')"
    assert_equal 1, run_catalogs([scenario('deprecated guard', "#{code}\n#{guard_resource}")], report: report_path)
    assert_deprecation_with_skip
    assert_occurs_once('synthetic skip deprecation')
  end

  def assert_deprecation_with_skip
    assert_counts(%w[1 1 0])
    assert_equal '0', report_suite.attributes['skipped']
    assert_equal 'Deprecation', report_suite.elements['testcase/failure'].attributes['type']
    assert_includes report_suite.elements['testcase/failure'].text, 'Dependency cycle check skipped'
  end

  def prepare_guard_module
    directory = module_inputs('guard_probe', code: 'include guard_probe')
    File.write(File.join(directory, 'manifests/init.pp'), "class guard_probe { #{guard_resource} }")
    File.write(File.join(directory, 'tests/manifests/shell.pp'), 'Exec { provider => shell } include guard_probe')
  end

  def guard_resource
    "exec { 'guard': command => '/usr/bin/true', onlyif => '[ -e /synthetic/missing ]' }"
  end

  def assert_skipped_case
    item = report_suite.get_elements('testcase').first
    assert_nil item.elements['system-out']
    assert_equal 'DependencyCycleUnavailable', item.elements['skipped'].attributes['type']
    ['Definition coverage: 1/1', 'Cycle freedom was not checked.', "'[' is not qualified"].each do |text|
      assert_includes item.elements['skipped'].text, text
    end
  end
end
