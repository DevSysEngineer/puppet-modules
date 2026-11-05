# frozen_string_literal: true

require_relative '../test_helper'
require 'project_tools/syntax'
require 'stringio'

# An invalid worker limit must not truncate an existing report.
class SyntaxParallelOptionsTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('syntax options ')
    @paths = []
  end

  def test_invalid_limit_keeps_existing_report
    report = File.join(@project, 'old.xml')
    File.write(report, 'old')
    %w[0 -1 1.5 invalid].each do |jobs|
      assert_equal 1, ProjectTools::Syntax.run(['--jobs', jobs, report, *@paths],
                                               console: StringIO.new, errors: StringIO.new)
      assert_equal 'old', File.read(report)
    end
  end
end
