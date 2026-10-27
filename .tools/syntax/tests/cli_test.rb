# frozen_string_literal: true

require_relative 'test_helper'
require 'project_tools/syntax'
require 'stringio'

# Help and option errors must not run validation or touch report files.
class SyntaxCliTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('syntax-cli-')
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
