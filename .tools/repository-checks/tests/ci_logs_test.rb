# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative 'ci_log_support'
require 'timeout'

# Execute the actual CI shell layer with controlled native statuses and separate streams.
class CiLogsTest < Minitest::Test
  include CiLogSupport

  def test_local_exit_trap_preserves_an_unclassified_failure
    output, errors, status = shell('source "$1"; ci_begin "Synthetic check"; printf "native diagnostic\n" >&2; exit 7')
    assert_equal 7, status.exitstatus
    assert_includes output, '[Result not classified] Synthetic check'
    assert_includes output, 'Original exit status: 7'
    assert_includes errors, 'native diagnostic'
    refute_includes output, '::group::'
    refute_includes output, 'section_start:'
  end

  def test_setup_failure_closes_platform_group_before_the_error_summary
    { 'GITHUB_ACTIONS' => '::endgroup::', 'GITLAB_CI' => 'section_end:' }.each do |platform, marker|
      script = 'source "$1"; ci_begin "Install synthetic bundle" details; ci_end 19 ERROR incomplete'
      output, _errors, status = shell(script, platform => 'true')
      assert_equal 19, status.exitstatus
      assert_operator output.index(marker), :<, output.index('[ERROR]')
      assert_includes output, '[collapsed=true]' if platform == 'GITLAB_CI'
      assert_equal 1, output.scan('[ERROR]').size
    end
  end

  def test_dynamic_group_text_cannot_inject_a_workflow_command
    script = 'source "$1"; ci_begin "$SYNTHETIC_NAME" details'
    output, _errors, status = shell(script, 'GITHUB_ACTIONS' => 'true',
                                            'SYNTHETIC_NAME' => "Example %\n::error::synthetic")
    assert status.success?
    assert_includes output, '::group::Example %25 ::error::synthetic'
    refute_match(/^::error::/, output)
  end

  def test_missing_executable_retains_its_native_diagnostic_and_status
    output, errors, status = shell('source "$1"; ci_begin Synthetic; missing_synthetic_ci_executable')
    assert_equal 127, status.exitstatus
    assert_includes errors, 'missing_synthetic_ci_executable'
    assert_includes output, 'Original exit status: 127'
    refute_includes output, '[PASSED]'
  end

  def test_native_progress_does_not_start_a_second_activity_process
    output, errors, status = shell('source "$1"; ci_begin Synthetic native; test -z "$CI_ACTIVITY_PID"')
    assert status.success?, output + errors
    assert_includes output, '[PASSED] Synthetic'
    refute_includes errors, '[PROGRESS]'
  end

  def test_immediate_failures_do_not_wait_for_the_activity_interval
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    12.times do
      _output, _errors, status = shell('source "$1"; ci_begin Synthetic; ci_end 19 ERROR incomplete')
      assert_equal 19, status.exitstatus
    end
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 10
  end

  def test_early_term_stops_activity_and_preserves_the_signal_exit_code
    script = 'source "$1"; ci_begin Synthetic; printf "activity:%s\n" "$CI_ACTIVITY_PID"; kill -TERM "$$"'
    output, _errors, status = shell(script)
    assert_equal 143, status.exitstatus
    assert_includes output, '[ERROR] Synthetic'
    assert_includes output, 'Execution: incomplete'
    pid = output[/activity:(\d+)/, 1].to_i
    assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
  end

  def test_activity_is_visible_while_the_command_is_still_waiting
    script = 'source "$1"; sleep() { command sleep 0.01; }; ' \
             'ci_begin Synthetic; read -r synthetic; ci_end 0 PASSED complete'
    Open3.popen3('bash', '-e', '-c', script, 'activity-test', @helper) do |input, output, errors, process|
      Timeout.timeout(10) { assert_live_activity(input, output, errors, process) }
    end
  end

  def assert_live_activity(input, output, errors, process)
    assert_includes output.readline, '[START]'
    assert_includes errors.readline, 'Still running'
    assert process.alive?
    input.puts 'finish'
    input.close
    assert_includes output.read, '[PASSED]'
    assert process.value.success?
  end
end
