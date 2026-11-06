# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../../shared/test_support/console_groups'
require 'project_tools/syntax'
require 'stringio'

# Help and option errors must not run validation or touch report files.
class SyntaxCliTest < Minitest::Test
  include ProjectToolsPackageSupport
  include ProjectToolsConsoleGroups

  def setup
    @project = Dir.mktmpdir('syntax-cli-')
  end

  def test_ci_cli_errors_leave_the_result_visible_and_junit_plain
    report = File.join(@project, 'report.xml')
    %w[GITHUB_ACTIONS GITLAB_CI].each do |platform|
      with_ci_platform(platform) do
        output, errors, status = Open3.capture3(Gem.bin_path('project-tools-syntax', 'syntax-junit'),
                                                report, 'missing.pp', chdir: @project)
        assert_equal 1, status.exitstatus, errors
        assert_ci_group(output, platform, name: 'Puppet syntax', outcome: 'ERROR')
        assert_error_report(output, report)
      end
    end
  end

  def assert_error_report(output, report)
    assert_includes output, '[ERROR] Puppet validator error | 1 file | missing.pp'
    refute_ci_markers(File.read(report))
  end

  def test_help_with_report_arguments_does_not_validate_or_replace_reports
    report = File.join(@project, 'report.xml')
    File.write(report, '<previous/>')
    %w[-h --help].each do |flag|
      console = StringIO.new
      errors = StringIO.new
      arguments = [report, File.join(@project, 'missing.pp'), flag]
      assert_equal 0, ProjectTools::Syntax.run(arguments, console: console, errors: errors)
      assert_empty errors.string
      assert_equal '<previous/>', File.read(report)
    end
  end

  def test_unknown_options_do_not_create_a_report
    report = File.join(@project, 'report.xml')
    errors = StringIO.new
    arguments = [report, 'missing.pp', '--unknown-option']
    assert_equal 1, ProjectTools::Syntax.run(arguments, console: StringIO.new, errors: errors)
    assert_includes errors.string, 'Usage:'
    refute_path_exists report
  end
end
