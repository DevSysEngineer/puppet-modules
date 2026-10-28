# frozen_string_literal: true

require_relative 'test_helper'

# Exercise the compiler runner with synthetic modules, never with the real module matrix.
class CatalogTest < Minitest::Test
  include CatalogTestSupport

  def prepare_module
    FileUtils.mkdir_p(File.join(@root, 'sample', 'manifests'))
    target = File.join(@root, 'must not exist')
    File.write(File.join(@root, 'sample', 'manifests', 'init.pp'), <<~PUPPET)
      class sample {
        if $facts['os']['name'] != 'Debian' { fail('wrong facts') }
        file { '#{target}': ensure => file, content => 'not applied' }
      }
    PUPPET
    target
  end

  def test_compiles_real_modules_with_supplied_facts_without_applying_or_writing_reports
    target = prepare_module
    input = scenario('valid & spaces', 'include sample')
    before = Dir.glob('**/*', File::FNM_DOTMATCH, base: @root)
    assert_equal 0, run_catalogs([input]), @console.string
    assert_includes @console.string, '[PASSED] Puppet catalogs'
    assert_primary_status('PASSED')
    assert_compact_success
    assert_equal before, Dir.glob('**/*', File::FNM_DOTMATCH, base: @root)
    refute_path_exists target
    assert_empty @errors.string
  end

  def test_duplicate_resources_fail_and_later_scenarios_still_compile_in_fresh_processes
    scenarios = [scenario('duplicate', "notify { 'same': } notify { 'same': }"),
                 scenario('first', 'class shared {} include shared'),
                 scenario('second', 'class shared {} include shared')]
    report = stale_report
    assert_equal 1, run_catalogs(scenarios, report: report)
    suite = report_suite
    assert_mixed_results(suite)
    refute_includes File.read(report), '<previous/>'
    assert_mixed_console
  end

  def assert_mixed_console
    assert_includes @console.string, '3 selected | 3 checked'
    assert_primary_status('FAILED')
    assert_occurs_once('Duplicate declaration')
    assert_includes @console.string, '[FINDING] Puppet catalogs | duplicate | Compilation failure'
    assert_compact_success
  end

  def assert_mixed_results(suite)
    assert_equal(%w[3 1 0], %w[tests failures errors].map { |key| suite.attributes[key] })
    assert_includes suite.elements['testcase/failure'].text, 'Duplicate declaration'
    assert_equal(%w[duplicate first second], suite.get_elements('testcase').map { |item| item.attributes['name'] })
  end

  def test_missing_dependencies_are_catalog_failures
    input = scenario('missing class', 'include nonexistent')
    assert_equal 1, run_catalogs([input])
    assert_includes @console.string, '1 failures | 0 errors'
    assert_includes @console.string, 'nonexistent'
    assert_primary_status('FAILED')
  end

  def test_native_output_remains_visible_and_does_not_corrupt_worker_results
    input = scenario('native', "warning('synthetic native warning')\ninline_template('<% puts \"native stdout\" %>')")
    assert_equal 0, run_catalogs([input], report: report_path)
    assert_primary_status('PASSED')
    assert_compact_success
    assert_includes @console.string, '| Native diagnostic'
    ['synthetic native warning', 'native stdout'].each do |message|
      assert_occurs_once(message)
      assert_includes report_suite.elements['testcase/system-out'].text, message
    end
  end

  def test_missing_inputs_and_invalid_facts_are_errors_and_retain_later_results
    File.write(@facts, '[]')
    missing = { name: 'missing', manifest: File.join(@root, 'absent.pp'), facts: @facts }
    invalid = scenario('invalid facts', "notify { 'example': }")
    report = report_path
    assert_equal 1, run_catalogs([missing, invalid], report: report)
    assert_equal(%w[2 0 2], %w[tests failures errors].map { |key| report_suite.attributes[key] })
    assert_includes @console.string, '2 selected | 0 checked'
    assert_includes @console.string, 'Expected a JSON object of facts'
    assert_primary_status('ERROR')
  end

  def test_interrupted_compiler_is_an_error_and_does_not_hide_later_success
    killed = scenario('interrupted', "inline_template('<% Process.kill(\"TERM\", Process.pid) %>')")
    valid = scenario('valid', "notify { 'example': }")
    assert_equal 1, run_catalogs([killed, valid], report: report_path)
    assert_equal(%w[2 0 1], %w[tests failures errors].map { |key| report_suite.attributes[key] })
    assert_includes @console.string, '2 selected | 1 checked'
    assert_primary_status('ERROR')
  end
end
