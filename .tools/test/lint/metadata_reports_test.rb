# frozen_string_literal: true

require_relative '../../lint/tests/test_helper'
require_relative 'metadata_cli_support'
require 'project_lint/puppet_junit'
require 'stringio'

# Native reporting must retain metadata failures and metadata-only success.
class MetadataReportsTest < Minitest::Test
  include MetadataCliSupport

  def test_json_and_junit_include_metadata_and_manifest_errors_once
    write_file('modules/profile/manifests/init.pp', "$values = [1] + [2]\n")
    scan('--json', 'modules')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_equal(1, JSON.parse(@output).flatten.count { |problem| problem['check'] == 'project_metadata' })
    assert_junit_findings
  end

  def test_clean_metadata_without_manifests_produces_a_valid_report
    metadata('modules/profile/metadata.json')
    scan('--json', 'modules')
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_equal [[]], JSON.parse(@output)
    assert_instance_of ProjectLint::PuppetJunit, ProjectLint::PuppetJunit.new(@output)
  end

  def test_excluded_manifests_still_report_the_metadata_scan
    metadata('modules/profile/metadata.json')
    write_file('modules/profile/manifests/init.pp', "$values = [1] + [2]\n")
    scan('--ignore-paths=modules/*/manifests/*', '--json', 'modules')
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_equal [[]], JSON.parse(@output)
  end

  def assert_junit_findings
    report = StringIO.new
    ProjectLint::PuppetJunit.new(@output).write(report, StringIO.new)
    assert_includes report.string, 'modules/profile/metadata.json:project_metadata'
    assert_includes report.string, 'project_arrays'
  end
end
