# frozen_string_literal: true

require_relative 'test_helper'

# Reporting is optional and must not change the native dependency verdict.
class DependencyCliTest < Minitest::Test
  include DependencyTestSupport

  def test_success_without_a_report
    write_module('library')
    assert_optional_report(0)
  end

  def test_conflicts_without_a_report
    write_module('library', dependencies: [dependency('example-missing')])
    assert_optional_report(1)
  end

  def test_configuration_errors_without_a_report
    @env['PROJECT_TOOLS_MODULEPATH'] = nil
    assert_optional_report(2)
  end

  def assert_optional_report(expected)
    output, errors, status = capture_cli
    assert_equal expected, status.exitstatus, output + errors
    refute_path_exists File.dirname(@report)
    scan(expected)
    assert_equal [output, errors], [@output, @errors]
  end

  def test_console_only_scan_preserves_existing_reports
    write_module('library')
    FileUtils.mkdir_p(File.dirname(@report))
    File.write(@report, 'previous report')
    _, _, status = capture_cli
    assert_equal 0, status.exitstatus
    assert_equal 'previous report', File.read(@report)
  end

  def test_invalid_arguments_fail_without_creating_a_report
    write_module('library')
    [%w[--junit], ['--junit', ''], %w[--junit report.txt], %w[old-report.xml], %w[--unknown]].each do |arguments|
      output, errors, status = capture_cli(*arguments)
      assert_equal 2, status.exitstatus, arguments.inspect
      assert_includes errors, 'configuration_error'
      refute_includes output, 'PASSED'
      refute_path_exists File.dirname(@report)
      refute_path_exists File.join(@project, 'old-report.xml')
    end
  end

  def capture_cli(*arguments)
    Open3.capture3(@env, RbConfig.ruby, dependency_executable, *arguments, chdir: @project)
  end
end
