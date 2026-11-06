# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require 'project_tools/shared/console'
require 'stringio'

# Grouping retains every affected identity and every distinct full diagnosis.
class SharedConsoleFindingsTest < Minitest::Test
  def setup
    @output = StringIO.new
    @console = ProjectTools::Shared::Console.new('Synthetic check', output: @output)
  end

  def test_only_identical_full_diagnostics_are_grouped_with_all_sorted_subjects
    %w[second first first].each { |subject| @console.finding("cause\ncontext\nlast line", subject: subject) }
    @console.finding("cause\ncontext\ndifferent last line", subject: 'third')
    refute_includes @output.string, 'Findings:'
    @console.finish(status: 'ERROR', execution: 'incomplete')
    assert_equal 2, @output.string.scan('cause').size
    assert_includes @output.string, "  last line\n  Affected (2 items):\n    - first\n    - second"
    assert_includes @output.string, "  different last line\n  Affected (1 item):\n    - third"
  end

  def test_findings_preserve_streams_and_finish_is_not_repeated
    errors = StringIO.new
    @console.finding('execution cause', output: errors)
    assert_empty errors.string
    @console.finish(status: 'ERROR', execution: 'incomplete')
    @console.finish(status: 'PASSED', execution: 'complete')
    assert_equal 1, errors.string.scan('execution cause').size
    refute_includes @output.string, 'execution cause'
    refute_includes @output.string, '[PASSED]'
  end
end
