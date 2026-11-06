# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../../shared/test_support/console_groups'

# A single failed scenario can also contain an independently skipped check.
class CatalogFindingsGroupsTest < Minitest::Test
  include CatalogTestSupport
  include ProjectToolsConsoleGroups

  def test_native_warnings_failures_and_skips_keep_separate_ci_groups_and_junit_outcomes
    %w[GITHUB_ACTIONS GITLAB_CI].each do |platform|
      @console = StringIO.new
      with_ci_platform(platform) { assert_equal 1, run_catalogs(inputs, report: report_path) }
      assert_ci_group(@console.string, platform, name: 'Puppet catalogs', outcome: 'FAILED')
      assert_group_order
      assert_report_outcomes
    end
  end

  def assert_report_outcomes
    assert_equal '1', report_suite.attributes['failures']
    assert_equal '0', report_suite.attributes['skipped']
    refute_ci_markers(File.read(report_path))
  end

  def inputs
    failure = "inline_template('<% Puppet.deprecation_warning(\"synthetic old API\", \"findings\") %>')"
    guard = "exec { 'guard': command => '/usr/bin/true', onlyif => 'test -e /synthetic/missing' }"
    [scenario('deprecated guard', "#{failure}\n#{guard}"), scenario('ordinary warning', "warning('ordinary notice')")]
  end

  def assert_group_order
    markers = ['[FAILED] Deprecated Puppet usage', '[SKIPPED] Dependency cycle check skipped',
               '[WARNING] Native Puppet warning']
    assert_ci_order(@console.string, *markers)
    assert_equal 2, @console.string.scan('    - deprecated guard').size
    assert_occurs_once('synthetic old API')
    assert_occurs_once('ordinary notice')
    assert_includes @console.string, 'Cycle freedom was not checked.'
    assert_includes @console.string, 'Execution: incomplete'
  end
end
