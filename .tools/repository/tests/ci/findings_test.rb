# frozen_string_literal: true

require_relative '../../../shared/test_support/bootstrap'
require_relative 'log_support'

# Deferred human output must survive the native outcome and leave no temporary files.
class CiFindingsTest < Minitest::Test
  include CiLogSupport

  def script(outcome)
    <<~BASH
      source "$1"
      ci_begin 'Synthetic lint' native
      ci_findings
      test "$(ruby -e 'puts(File.stat(ARGV.first).mode & 0777)' "$CI_LOG_FINDINGS")" = 384
      printf 'complete diagnosis\nlast line\n' > "$CI_LOG_FINDINGS"
      #{outcome}
    BASH
  end

  def test_findings_follow_the_outcome_and_temporary_files_are_removed
    %w[GITHUB_ACTIONS GITLAB_CI].product([0, 7]).each do |platform, code|
      outcome = code.zero? ? 'PASSED' : 'FAILED'
      output, errors, status = shell(script("ci_end #{code} #{outcome} complete"),
                                     platform => 'true', 'TMPDIR' => @project)
      assert_equal code, status.exitstatus, errors
      assert_ci_group(output, platform, name: 'Synthetic lint', outcome: outcome)
      assert_operator output.index("[#{outcome}]"), :<, output.index('complete diagnosis')
      assert_includes output, "complete diagnosis\nlast line"
      assert_empty Dir.glob(File.join(@project, 'project-ci-findings.*'))
    end
  end

  def test_unexpected_exit_preserves_findings_and_native_code
    output, errors, status = shell(script('exit 23'), 'TMPDIR' => @project)
    assert_equal 23, status.exitstatus, errors
    assert_operator output.index('[ERROR]'), :<, output.index('complete diagnosis')
    assert_empty Dir.glob(File.join(@project, 'project-ci-findings.*'))
  end

  def test_unreadable_findings_prevent_a_successful_result
    output, _errors, status = shell(script('rm "$CI_LOG_FINDINGS"; ci_end 0 PASSED complete'))
    assert_equal 1, status.exitstatus
    assert_includes output, '[ERROR] Synthetic lint'
    assert_includes output, 'Execution: incomplete'
    refute_includes output, '[PASSED]'
    assert_includes output, 'Original exit status: 0'
  end

  def test_exit_trap_does_not_hide_a_findings_read_error
    output, _errors, status = shell(script('rm "$CI_LOG_FINDINGS"; exit 0'))
    assert_equal 1, status.exitstatus
    assert_includes output, '[ERROR] Synthetic lint'
  end

  def test_termination_preserves_findings_and_removes_the_temporary_file
    output, errors, status = shell(script('kill -TERM $$'), 'TMPDIR' => @project)
    assert_equal 143, status.exitstatus, errors
    assert_includes output, 'complete diagnosis'
    assert_empty Dir.glob(File.join(@project, 'project-ci-findings.*'))
  end
end
