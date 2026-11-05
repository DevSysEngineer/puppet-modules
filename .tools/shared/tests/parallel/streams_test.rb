# frozen_string_literal: true

require_relative 'support'

# File-backed streams must preserve both channels even beyond ordinary pipe capacity.
class ParallelStreamsTest < Minitest::Test
  include ParallelTestSupport

  def test_large_stdout_and_stderr_are_complete_and_separate
    %w[Alpha Beta].each do |name|
      probe(name, "$stdout.write('#{name}-out\\n' * 20_000); $stderr.write('#{name}-err\\n' * 20_000); assert true")
    end
    run_tests
    assert_success
    %w[Alpha Beta].product(%w[out err]).each do |name, channel|
      assert_equal 20_000, @output.scan("#{name}-#{channel}").size
    end
    assert_operator @output.index('[PASSED]'), :<, @output.index('Alpha-out')
  end

  def test_worker_report_write_failure_preserves_native_failure_and_other_reports
    broken_report_probe
    probe('Beta')
    run_tests('2', report: 'reports')
    refute @status.success?
    assert_includes @output, 'Execution: incomplete'
    assert_includes @output, 'native failure survives report error'
    assert_includes @output, 'Cannot write test JUnit reports:'
    assert identities('reports').key?(%w[Beta test_contract passed])
  end

  def broken_report_probe
    probe('Alpha', <<~RUBY)
      directory = ProjectTools::ParallelWorker::CONFIG.fetch('reports')
      FileUtils.remove_entry(directory)
      File.write(directory, 'blocked')
      flunk 'native failure survives report error'
    RUBY
  end
end
