# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'metadata_cli_support'

# Console-only checks and fixes must not depend on report storage.
class MetadataCliTest < Minitest::Test
  include MetadataCliSupport

  def test_success_has_the_same_verdict_with_optional_junit
    metadata('modules/profile/metadata.json')
    assert_optional_report(0)
  end

  def test_failure_has_the_same_verdict_with_optional_junit
    metadata('modules/profile/metadata.json', version: '0.1.0')
    assert_optional_report(1)
  end

  def assert_optional_report(expected)
    scan
    assert_equal expected, @status.exitstatus, @output + @errors
    console = [@output, @errors]
    refute_path_exists File.join(@directory, '.reports')
    scan('--junit', '.reports/metadata.xml')
    assert_equal expected, @status.exitstatus, @output + @errors
    assert_equal console, [@output, @errors]
    assert_path_exists File.join(@directory, '.reports/metadata.xml')
  end

  def test_fix_needs_no_report_and_preserves_an_existing_report
    path = 'modules/profile/metadata.json'
    metadata(path, version: '0.1.0')
    write_file('.reports/metadata.xml', 'previous report')
    scan('--fix')
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_equal '7.4.0', JSON.parse(contents(path)).fetch('version')
    assert_includes @output, ': fixed:'
    assert_equal 'previous report', contents('.reports/metadata.xml')
  end

  def test_invalid_arguments_prevent_fixes_and_report_creation
    path = 'modules/profile/metadata.json'
    metadata(path, version: '0.1.0')
    original = contents(path)
    [%w[--junit], ['--junit', ''], %w[old-report.xml], %w[--unknown]].each do |arguments|
      scan('--fix', *arguments)
      assert_equal 2, @status.exitstatus, arguments.inspect
      assert_equal original, contents(path)
      refute_path_exists File.join(@directory, '.reports')
      refute_path_exists File.join(@directory, 'old-report.xml')
    end
  end
end
