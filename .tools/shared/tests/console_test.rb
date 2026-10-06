# frozen_string_literal: true

require_relative '../test_support/bootstrap'
require 'project_tools/shared/console'
require 'stringio'
require 'timeout'

# Exercise presentation with controlled events, without waiting for the production interval.
class SharedConsoleTest < Minitest::Test
  def setup
    @time = 0
    @output = StringIO.new
    @console = ProjectTools::Shared::Console.new('Synthetic check', output: @output, clock: -> { @time })
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
    assert_equal 2, @output.string.scan('example file:2:3 [RULE] failed').size
    refute_match(/^::error::/, @output.string)
    refute_includes @output.string, "\e"
  end

  def test_success_keeps_warning_details_without_creating_a_report
    @console.during do
      @console.finding('example.pp:1:1: warning: synthetic')
      @console.finish(status: 'PASSED', execution: 'complete', facts: ['Warnings: 1'],
                      details: ['example.pp:1:1: warning: synthetic'])
    end
    assert_equal 1, @output.string.scan('[PASSED]').size
    assert_equal 2, @output.string.scan('warning: synthetic').size
    refute_includes @output.string, 'JUnit'
  end

  def test_flushed_progress_precedes_completion_and_term_keeps_signal_status
    Open3.popen3(RbConfig.ruby, '-e', signal_script) do |input, output, errors, process|
      Timeout.timeout(10) { assert_signal_result(input, output, errors, process) }
    end
  end

  def signal_script
    <<~RUBY
      require 'project_tools/shared/console'
      console = ProjectTools::Shared::Console.new('Synthetic signal check')
      console.during do
        console.advance(unit: 'files', total: 2)
        console.progress
        STDIN.read
      end
    RUBY
  end

  def assert_signal_result(input, output, errors, process)
    assert_includes output.readline, '[START]'
    assert_includes output.readline, '1/2 files processed'
    Process.kill('TERM', process.pid)
    input.close
    assert_includes output.read, 'Execution: incomplete'
    assert_empty errors.read
    assert_equal Signal.list.fetch('TERM'), process.value.termsig
  end
end
