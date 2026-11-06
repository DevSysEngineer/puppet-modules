# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require_relative '../../test_support/console_groups'
require 'project_tools/shared/console'
require 'stringio'

# Exercise presentation with controlled events, without waiting for the production interval.
class SharedConsoleTest < Minitest::Test
  include ProjectToolsConsoleGroups

  def setup
    @time = 0
    @output = StringIO.new
    with_ci_platform(nil) do
      @console = ProjectTools::Shared::Console.new('Synthetic check', output: @output, clock: -> { @time })
    end
  end

  def test_progress_counts_only_completed_units_and_distinguishes_activity
    @time = 15
    @console.progress
    assert_includes @output.string, 'Still running | 15 s | no new results'
    refute_includes @output.string, '0 files'
    @console.advance(unit: 'files', total: 3)
    @time = 30
    @console.progress
    assert_includes @output.string, '1/3 files processed | 30 s'
  end

  def test_incomplete_result_has_no_report_or_success_claim
    @console.finish(status: 'FAILED', execution: 'incomplete', facts: ['Files: 1 checked of 3'])
    refute_includes @output.string, 'JUnit written:'
    refute_includes @output.string, 'PASSED'
  end

  def test_start_full_diagnostics_and_caller_status_use_safe_terminal_text
    @console.during do
      @console.finding("first line\n::error::literal text\e[31m\nlast line\t\r\0", subject: 'example.pp:2:3')
      refute_includes @output.string, 'first line'
      @console.finish(status: 'FAILED', execution: 'complete', facts: ['Checks: 1'])
    end
    assert_full_safe_diagnostic
  end

  def assert_full_safe_diagnostic
    text = @output.string
    assert_equal 1, text.scan('[START]').size
    assert_equal 1, text.scan('Findings:').size
    assert_operator text.index('[FAILED]'), :<, text.index('first line')
    assert_equal ['FAILED'], text.scan(/^\[(PASSED|FAILED|ERROR|SKIPPED)\]/).flatten
    assert_includes text, 'Execution: complete'
    assert_safe_diagnostic_lines
  end

  def assert_safe_diagnostic_lines
    %w[first last].each { |word| assert_equal 1, @output.string.scan("#{word} line").size }
    refute_match(/^::error::/, @output.string)
    refute_match(/[\e\t\r\0]/, @output.string)
  end

  def test_failure_stops_activity_and_keeps_available_diagnostics
    threads = Thread.list
    assert_raises(IOError) do
      @console.during do
        @console.finding("example file:2:3 [RULE] failed\n::error::not an annotation\e[31m")
        raise IOError, 'synthetic execution failure'
      end
    end
    assert_equal threads, Thread.list
    assert_incomplete_diagnostics
  end

  def assert_incomplete_diagnostics
    assert_includes @output.string, '[ERROR] Synthetic check'
    assert_includes @output.string, 'Execution: incomplete'
    assert_equal 1, @output.string.scan('example file:2:3 [RULE] failed').size
    refute_match(/^::error::/, @output.string)
    refute_includes @output.string, "\e"
  end

  def test_success_keeps_warning_details_without_creating_a_report
    @console.during do
      @console.finding('example.pp:1:1: warning: synthetic')
      @console.finish(status: 'PASSED', execution: 'complete', facts: ['Warnings: 1'])
    end
    assert_equal 1, @output.string.scan('[PASSED]').size
    assert_equal 1, @output.string.scan('warning: synthetic').size
    refute_includes @output.string, 'JUnit'
  end
end
