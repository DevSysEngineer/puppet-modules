# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../../../shared/test_support/console_groups'
require 'project_lint/puppet_junit'
require 'stringio'

# Native structured kinds govern console groups without changing conversion policy.
class PuppetJunitFindingsTest < Minitest::Test
  include ProjectToolsConsoleGroups

  def test_ci_groups_are_sorted_and_xml_keeps_native_failure_cases
    %w[GITHUB_ACTIONS GITLAB_CI].each do |platform|
      with_ci_platform(platform) { convert }
      assert_equal %w[FAILED WARNING INFO], @console.string.scan(/\[(\w+)\] synthetic/).flatten
      assert_equal 3, @console.string.scan('Diagnostic:').size
      assert_equal 1, @console.string.scan('second context line').size
      assert_report_outcomes
    end
  end

  def assert_report_outcomes
    assert_includes @xml.string, 'failures="2"'
    refute_ci_markers(@xml.string)
    assert_empty @errors.string
  end

  def test_report_error_precedes_the_preserved_lint_findings
    problem = { path: 'example.pp', line: 1, column: 1, kind: 'error', check: 'synthetic', message: 'rejected' }
    console = StringIO.new
    Dir.mktmpdir('unwritable lint report ') do |directory|
      input = StringIO.new(JSON.generate([[problem]]))
      assert_equal 1, ProjectLint::PuppetJunit.report(directory, input, console, console)
    end
    assert_ci_order(console.string, '[ERROR] Puppet lint report', '[FAILED] synthetic')
    assert_equal 1, console.string.scan('rejected').size
    refute_includes console.string, 'JUnit written:'
  end

  def convert
    problems = %w[fixed warning error ignored].map.with_index do |kind, index|
      { path: 'example.pp', line: index + 1, column: 1, kind: kind,
        check: "synthetic_#{kind}", message: kind == 'error' ? "cause\nsecond context line" : 'native message' }
    end
    @xml = StringIO.new
    @console = StringIO.new
    @errors = StringIO.new
    assert_equal 0, ProjectLint::PuppetJunit.convert(StringIO.new(JSON.generate([problems])), @xml, @console, @errors)
  end
end
