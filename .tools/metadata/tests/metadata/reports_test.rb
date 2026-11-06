# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../metadata_cli_support'
require_relative '../../../shared/test_support/console_groups'
require 'rexml/document'

# Metadata reports stand alone and never execute Puppet checks.
class MetadataReportsTest < Minitest::Test
  include MetadataCliSupport
  include ProjectToolsConsoleGroups

  def test_ci_cli_success_is_visible_and_junit_stays_plain
    metadata('modules/profile/metadata.json')
    %w[GITHUB_ACTIONS GITLAB_CI].each do |platform|
      with_ci_platform(platform) { scan('--junit', '.reports/metadata.xml') }
      assert_equal 0, @status.exitstatus, @output + @errors
      assert_ci_group(@output, platform, name: 'Metadata', outcome: 'PASSED')
      refute_ci_markers(contents('.reports/metadata.xml'))
    end
  end

  def suite
    REXML::Document.new(contents('.reports/metadata.xml')).root.elements['testsuite']
  end

  def test_missing_metadata_is_reported_once_without_linting_manifests
    write_file('modules/profile/manifests/init.pp', "$values = [1] + [2]\n")
    with_ci_platform('GITHUB_ACTIONS') { scan('--junit', '.reports/metadata.xml') }
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_equal(%w[1 0], %w[failures errors].map { |key| suite.attributes[key] })
    assert_final_metadata_finding
    report = contents('.reports/metadata.xml')
    assert_includes report, 'modules/profile/metadata.json'
    refute_includes report, 'project_arrays'
  end

  def assert_final_metadata_finding
    assert_includes @output, '::group::[FAILED] project_metadata'
    assert_equal 1, @output.scan('modules/profile/metadata.json:').size
    assert_operator @output.index('[FAILED]'), :<, @output.index('modules/profile/metadata.json:')
    refute_includes @output, '[FINDING]'
  end

  def test_clean_metadata_without_manifests_produces_success_cases
    metadata('modules/profile/metadata.json')
    scan('--junit', '.reports/metadata.xml')
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_equal '2', suite.attributes['tests']
    assert_equal '0', suite.attributes['failures']
  end

  def test_fixed_findings_are_reported_without_failure
    metadata('modules/profile/metadata.json', version: '0.1.0')
    scan('--fix', '--junit', '.reports/metadata.xml')
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_equal '0', suite.attributes['failures']
    assert_includes contents('.reports/metadata.xml'), '<system-out>'
    refute_includes contents('.reports/metadata.xml'), '<failure'
  end

  def test_unwritable_report_is_an_execution_error
    FileUtils.mkdir_p(File.join(@directory, '.reports/metadata.xml'))
    scan('--junit', '.reports/metadata.xml')
    assert_equal 2, @status.exitstatus
    assert_includes @errors, 'metadata:'
  end
end
