# frozen_string_literal: true

require_relative '../test_helper'
require 'project_tools/syntax'
require 'stringio'

# Native parser cases must retain selection and classification across worker limits.
class SyntaxParallelEquivalenceTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('syntax parallel ')
    write('valid.pp', "$value = 'synthetic'")
    write('invalid.pp', '$value = [')
    @paths = %w[invalid.pp valid.pp missing.pp].map { |file| File.join(@project, file) }
  end

  def test_parallel_and_native_reports_have_identical_order_and_outcomes
    reports = [1, 2, 4].map do |jobs|
      console = StringIO.new
      report = File.join(@project, "#{jobs}.xml")
      assert_equal 1, ProjectTools::Syntax.run(['--jobs', jobs.to_s, report, *@paths],
                                               console: console, errors: StringIO.new)
      assert_includes console.string, 'Results: 1 failures | 1 errors'
      File.read(report)
    end
    assert_equal [reports.first], reports.uniq
  end
end
