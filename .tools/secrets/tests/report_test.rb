# frozen_string_literal: true

require_relative 'test_helper'

# Requested reports preserve scan findings and never contain source fragments.
class SecretsReportTest < SecretsTest
  def test_url_password_is_removed_from_metadata_paths
    value = 'synthetic-url-password'
    path = write("#{value}.txt", "ssh://user:#{value}@example.test/repository")
    report = File.join(@directory, 'report.xml')
    scan('--junit', report, path)
    assert_complete_scan
    assert_masked(value)
    refute_includes File.read(report), value
    assert_console_path_masked(path, value)
  end

  def assert_console_path_masked(path, value)
    output = StringIO.new
    assert_equal 1, ProjectTools::Secrets.run([path], output: output)
    refute_includes output.string, value
  end

  def test_embedded_yaml_command_value_is_removed_from_metadata_paths
    value = 'synthetic-yaml-command'
    path = write("#{value}.yaml", "script: tool --password=#{value}\n")
    report = File.join(@directory, 'report.xml')
    scan('--junit', report, path)
    assert_complete_scan
    assert_masked(value)
    refute_includes File.read(report), value
    assert_console_path_masked(path, value)
  end

  def test_junit_contains_only_metadata_and_retains_scan_status
    path = write('settings.txt', 'password=synthetic-report')
    report = File.join(@directory, 'report.xml')
    scan('--junit', report, path)
    assert_equal 1, @status.exitstatus
    assert @report['report_written']
    refute_includes File.read(report), 'synthetic-report'
    assert_includes File.read(report), 'sensitive_assignment'
    assert_includes File.read(report), 'failures="1"'
    assert_report_preserved(path, report)
  end

  def assert_report_preserved(path, report)
    scan(path)
    assert_equal 1, @status.exitstatus
    assert_includes File.read(report), 'failures="1"'
    scan('--junit', File.join(@directory, 'absent', 'report.xml'), path)
    assert_equal 2, @status.exitstatus
    assert_includes @report['errors'], 'report_write_failed'
    assert_no_disclosure('synthetic-report')
  end
end
