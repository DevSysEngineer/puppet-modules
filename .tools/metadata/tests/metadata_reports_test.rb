# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'metadata_cli_support'
require 'rexml/document'

# Metadata reports stand alone and never execute Puppet checks.
class MetadataReportsTest < Minitest::Test
  include MetadataCliSupport

  def suite
    REXML::Document.new(contents('.reports/metadata.xml')).root.elements['testsuite']
  end

  def test_missing_metadata_is_reported_once_without_linting_manifests
    write_file('modules/profile/manifests/init.pp', "$values = [1] + [2]\n")
    scan('--junit', '.reports/metadata.xml')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_equal '1', suite.attributes['failures']
    assert_equal '0', suite.attributes['errors']
    assert_includes contents('.reports/metadata.xml'), 'modules/profile/metadata.json'
    refute_includes contents('.reports/metadata.xml'), 'project_arrays'
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
