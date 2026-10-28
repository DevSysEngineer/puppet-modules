# frozen_string_literal: true

require_relative 'test_helper'

# Exercise the actual native runtime, including stdlib's deprecated forwarding function.
class CatalogDeprecationsTest < Minitest::Test
  include CatalogTestSupport

  def native(code)
    "inline_template('<% #{code} %>')"
  end

  def test_native_deprecations_are_failures_and_other_scenarios_continue
    inputs = [scenario('native', native('Puppet.deprecation_warning("synthetic native", "first")')),
              scenario('ordinary', "warning('deprecated deprecation warning, ordinary text')"),
              scenario('valid', "notify { 'valid': }")]
    assert_equal 1, run_catalogs(inputs, report: report_path)
    assert_primary_status('FAILED')
    assert_counts(%w[3 1 0])
    assert_failure_type('Deprecation')
    assert_includes @console.string, 'native | Deprecated Puppet usage'
    assert_occurs_once('synthetic native')
    assert_includes @console.string, '3 selected | 3 checked'
  end

  def test_real_stdlib_legacy_function_fails_and_namespaced_function_passes_despite_inherited_suppression
    FileUtils.ln_s(File.join(ProjectTools::Catalog::ROOT, 'stdlib'), File.join(@root, 'stdlib'))
    previous = ENV.fetch('STDLIB_LOG_DEPRECATIONS', nil)
    ENV['STDLIB_LOG_DEPRECATIONS'] = 'false'
    inputs = [scenario('legacy', "ensure_packages(['synthetic-package'], { 'ensure' => 'installed' })"),
              scenario('namespaced', "stdlib::ensure_packages(['synthetic-package'], { 'ensure' => 'installed' })")]
    assert_equal 1, run_catalogs(inputs, report: report_path)
    assert_stdlib_results
    assert_equal 'false', ENV.fetch('STDLIB_LOG_DEPRECATIONS', nil)
  ensure
    ENV['STDLIB_LOG_DEPRECATIONS'] = previous
  end

  def assert_stdlib_results
    cases = report_suite.get_elements('testcase')
    assert_counts(%w[2 1 0])
    assert_failure_type('Deprecation')
    assert_includes cases.first.elements['failure'].text, 'please use stdlib::ensure_packages instead.'
    assert_includes cases.last.elements['system-out'].text, 'Compiled '
    assert_occurs_once('please use stdlib::ensure_packages instead.')
  end

  def assert_counts(expected)
    assert_equal(expected, %w[tests failures errors].map { |key| report_suite.attributes[key] })
  end

  def assert_failure_type(type)
    assert_equal type, report_suite.elements['testcase/failure'].attributes['type']
  end

  def test_multiple_and_deduplicated_deprecations_make_one_testcase
    code = native('2.times { Puppet.deprecation_warning("first synthetic", "first") }; ' \
                  'Puppet.puppet_deprecation_warning("second synthetic", file: "example.pp", line: 12)')
    assert_equal 1, run_catalogs([scenario('multiple', code)], report: report_path)
    assert_counts(%w[1 1 0])
    %w[first second].each { |word| assert_occurs_once("#{word} synthetic") }
    assert_includes @console.string, 'Native deprecations: 2'
    assert_includes @console.string, 'example.pp'
  end

  def test_compilation_error_remains_primary_with_additional_deprecations
    code = "#{native('Puppet.deprecation_warning("earlier synthetic", "first")')}\nfail('synthetic failure')"
    assert_equal 1, run_catalogs([scenario('both', code)], report: report_path)
    assert_failure_type('CatalogFailure')
    assert_counts(%w[1 1 0])
    assert_includes @console.string, 'both | Compilation failure'
    ['earlier synthetic', 'synthetic failure'].each { |message| assert_occurs_once(message) }
  end

  def test_reset_or_disabled_registration_cannot_pass
    inputs = suppression_scenarios
    assert_equal 1, run_catalogs(inputs, report: report_path)
    assert_primary_status('ERROR')
    assert_counts(%w[5 0 4])
    assert_includes @console.string, 'registration is unavailable or was reset'
    assert_includes @console.string, 'detection was disabled'
  end

  def suppression_scenarios
    [scenario('reset', native('$deprecation_warnings = nil')),
     scenario('suppressed', native('Puppet[:disable_warnings] = ["deprecations"]')),
     scenario('stdlib suppressed', native('ENV["STDLIB_LOG_DEPRECATIONS"] = "false"')),
     scenario('strict off', native('Puppet[:strict] = :off')),
     scenario('later valid', '')]
  end

  def test_saturated_native_registry_reports_incomplete_detection
    code = native('100.times { |index| Puppet.deprecation_warning("synthetic limit " + index.to_s, index) }')
    assert_equal 1, run_catalogs([scenario('limit', code)], report: report_path)
    assert_primary_status('ERROR')
    assert_counts(%w[1 0 1])
    assert_includes report_suite.elements['testcase/error'].text, 'registration limit reached'
    assert_includes @console.string, 'Execution: incomplete'
  end

  def test_language_deprecations_retain_source_before_native_display_limits
    directory = File.join(@root, 'plan', 'manifests')
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, 'init.pp'), 'class plan {}')
    input = scenario('language', "#{native('Puppet[:max_deprecations] = 0')}\ninclude plan")
    assert_equal 1, run_catalogs([input], report: report_path)
    assert_failure_type('Deprecation')
    assert_includes @console.string, 'future reserved word'
    assert_includes @console.string, 'plan/manifests/init.pp:1'
  end
end
