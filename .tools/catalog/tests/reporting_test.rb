# frozen_string_literal: true

require_relative 'test_helper'

# Reports are optional and must retain failure status and source files.
class CatalogReportingTest < Minitest::Test
  include CatalogTestSupport

  def test_empty_selection_is_an_error
    assert_equal 1, run_catalogs([], report: File.join(@root, 'reports', 'catalog.xml'))
    assert_equal '1', report_suite.attributes['errors']
    assert_includes @console.string, 'No catalog scenarios selected.'
  end

  def test_report_is_opt_in_and_existing_report_is_preserved_without_request
    report = File.join(@root, 'catalog.xml')
    File.write(report, '<previous/>')
    assert_equal 0, run_catalogs([scenario('valid', "notify { 'example': }")])
    assert_equal '<previous/>', File.read(report)
    refute_includes @console.string, 'JUnit written:'
  end

  def test_report_write_failure_preserves_compile_diagnostics_and_fails
    blocker = File.join(@root, 'blocker')
    File.write(blocker, 'ordinary file')
    input = scenario('bad', "fail('synthetic compilation failure')")
    assert_equal 1, run_catalogs([input], report: File.join(blocker, 'catalog.xml'))
    assert_includes @console.string, 'synthetic compilation failure'
    assert_includes @console.string, '[ERROR] Puppet catalogs'
    assert_includes @errors.string, 'Cannot write catalog JUnit report'
    refute_includes @console.string, 'JUnit written:'
    assert_equal 'ordinary file', File.read(blocker)
  end

  def test_invalid_report_extension_fails_before_compilation
    input = scenario('not executed', "fail('must not compile')")
    report = File.join(@root, 'wrong.txt')
    assert_equal 1, run_catalogs([input], report: report)
    refute_includes @console.string, 'must not compile'
    refute_path_exists report
  end

  def test_cli_help_and_unknown_arguments_do_not_compile
    cli = File.expand_path('../compile.rb', __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, cli, '--help')
    assert status.success?, output
    assert_includes output, '--junit'
    output, status = Open3.capture2e(RbConfig.ruby, cli, '--unknown')
    assert_equal 1, status.exitstatus
    assert_includes output, 'Usage:'
    refute_includes output, 'resources'
  end
end
