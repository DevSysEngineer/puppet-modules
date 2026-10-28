# frozen_string_literal: true

require_relative 'test_helper'

# Coverage findings retain their per-scenario policy while successful details stay in JUnit.
class CatalogCoverageTest < Minitest::Test
  include CatalogTestSupport

  def test_coverage_reports_indirect_declarations_and_excludes_unrealized_defines
    prepare_coverage_module
    assert_equal 0, run_catalogs(nil, report: report_path)
    assert_includes @console.string, '[FINDING] Puppet catalogs | sample/default [debian] | Coverage review: 3/5'
    assert_includes @console.string, 'Missing definitions: class sample::missing, define sample::unused'
    assert_primary_status('PASSED')
    assert_compact_success
    refute_includes @console.string, 'Compilation failure'
    assert_partial_coverage_details
  end

  def assert_partial_coverage_details
    details = report_suite.elements['testcase/system-out'].text
    assert_match(/Compiled \d+ resources\./, details)
    assert_includes details, 'Definition coverage: 3/5'
    assert_includes details, 'Compiled definitions: class sample, class sample::child, define sample::item'
    missing = 'Missing definitions (review required): class sample::missing, define sample::unused'
    assert_includes details, missing
  end

  def test_complete_coverage_is_silent_and_kept_in_junit
    prepare_coverage_module
    manifest = File.join(@root, 'sample', 'tests', 'manifests', 'default.pp')
    File.write(manifest, "include sample, sample::missing\nrealize(Sample::Unused['virtual'])")
    assert_equal 0, run_catalogs(nil, report: report_path)
    assert_primary_status('PASSED')
    assert_compact_success
    refute_includes @console.string, '[FINDING]'
    assert_complete_coverage_details
  end

  def assert_complete_coverage_details
    details = report_suite.elements['testcase/system-out'].text
    assert_includes details, 'Definition coverage: 5/5'
    assert_includes details, 'class sample::missing, define sample::item, define sample::unused'
    refute_includes details, 'Missing definitions'
  end

  def test_multiple_failures_keep_complete_diagnostics_once_without_claiming_coverage
    prepare_failed_coverage
    assert_equal 1, run_catalogs(nil, report: report_path)
    assert_primary_status('FAILED')
    assert_equal 2, @console.string.scan('| Compilation failure').size
    assert_complete_failure_diagnostics
    assert_includes @console.string, '2 selected | 2 checked'
    refute_includes @console.string, 'Coverage review'
    refute_includes File.read(report_path), 'Definition coverage'
  end

  def assert_complete_failure_diagnostics
    assert_match(/line: 2, column: 1/, @console.string)
    ['first line', 'middle line', 'last diagnostic line', 'independent compilation failure'].each do |line|
      assert_occurs_once(line)
      assert_includes File.read(report_path), line
    end
  end

  def prepare_failed_coverage
    prepare_coverage_module
    manifest = File.join(@root, 'sample', 'tests', 'manifests', 'default.pp')
    message = ['first line', 'middle line', 'last diagnostic line'].join("\n")
    File.write(manifest, "include sample\nfail('#{message}')")
    second = File.join(File.dirname(manifest), 'second.pp')
    File.write(second, "fail('independent compilation failure')")
  end

  def prepare_coverage_module
    directory = module_inputs('sample', code: 'include sample')
    File.write(File.join(directory, 'manifests', 'init.pp'), <<~PUPPET)
      class sample { include sample::child; sample::item { 'included': } @sample::unused { 'virtual': } }
      class sample::child {}
      class sample::missing {}
      define sample::item() {}
      define sample::unused() {}
    PUPPET
  end
end
