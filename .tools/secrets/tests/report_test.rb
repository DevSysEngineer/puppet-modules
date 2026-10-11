# frozen_string_literal: true

require_relative 'test_helper'

# Requested reports preserve scan findings and never contain source fragments.
class SecretsReportTest < SecretsTest
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
