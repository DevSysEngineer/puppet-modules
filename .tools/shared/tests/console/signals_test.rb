# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require 'timeout'

# Verify flushing and process interruption through a real console consumer.
class SharedConsoleSignalsTest < Minitest::Test
  def test_flushed_progress_precedes_completion_and_term_keeps_signal_status
    environment = { 'GITHUB_ACTIONS' => nil, 'GITLAB_CI' => nil }
    Open3.popen3(environment, RbConfig.ruby, '-e', signal_script) do |input, output, errors, process|
      Timeout.timeout(10) { assert_signal_result(input, output, errors, process) }
    end
  end

  def signal_script
    <<~RUBY
      require 'project_tools/shared/console'
      console = ProjectTools::Shared::Console.new('Synthetic signal check')
      console.during do
        console.finding("first diagnostic\\nlast diagnostic")
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
    final = output.read
    assert_signal_diagnostics(final)
    assert_empty errors.read
    assert_equal Signal.list.fetch('TERM'), process.value.termsig
  end

  def assert_signal_diagnostics(final)
    assert_includes final, 'Execution: incomplete'
    assert_includes final, "  first diagnostic\n  last diagnostic"
  end
end
