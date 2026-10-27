# frozen_string_literal: true

require_relative '../../../shared/test_support/bootstrap'
require_relative 'log_support'

# A failed Ruby process is an offense result only when the native report was produced.
class CiRubyStepsTest < Minitest::Test
  include CiLogSupport

  def ruby_script(steps)
    steps.find { |item| item.fetch('run', '').include?('bundle exec rubocop') }.fetch('run')
  end

  def ruby_scripts
    github = guide_configuration('jobs').dig('jobs', 'ruby_lint', 'steps')
    gitlab = guide_configuration('.check_setup').dig('ruby_lint', 'script').join("\n")
    scripts = [ruby_script(workflow_steps('ruby_lint')), ruby_script(github), gitlab]
    scripts.map do |script|
      "source \"$1\"\n#{script[/ci_begin 'Ruby lint' native.*?^\s*esac/m]}"
    end
  end

  def test_offenses_and_runtime_errors_keep_distinct_outcomes_in_all_ci_examples
    ruby_scripts.each do |script|
      { 0 => ['PASSED', 'Execution: complete'], 1 => ['FAILED', 'Reason: RuboCop offenses'],
        2 => ['ERROR', 'Reason: RuboCop could not complete'] }.each do |code, (outcome, detail)|
        assert_ruby_outcome(script, code, outcome, detail)
      end
    end
  end

  def assert_ruby_outcome(script, code, outcome, detail)
    native = "bundle() { printf 'native diagnostic\\n' >&2; printf '<testsuites/>' > \"${@: -1}\"; return #{code}; }\n"
    output, errors, status = shell(native + script, 'PROJECT_REPORT_DIR' => 'results with spaces')
    assert_equal code, status.exitstatus, output + errors
    assert_includes output, "[#{outcome}] Ruby lint"
    assert_includes errors, 'native diagnostic'
    assert_includes output, detail
  end

  def test_exit_one_without_a_new_nonempty_report_is_an_execution_error
    ruby_scripts.each do |script|
      ['', ': > "${@: -1}";'].each do |write_report|
        native = "bundle() { printf 'synthetic load error\\n' >&2; #{write_report} return 1; }\n"
        output, errors, status = shell(native + script, 'PROJECT_REPORT_DIR' => 'results with spaces')
        assert_unconfirmed_failure(output, errors, status)
      end
    end
  end

  def assert_unconfirmed_failure(output, errors, status)
    assert_equal 1, status.exitstatus, output + errors
    assert_includes output, '[ERROR] Ruby lint'
    assert_includes output, 'Execution: incomplete'
    assert_includes output, 'without a new, non-empty report'
    refute_includes output, '[FAILED]'
    refute_includes output, 'JUnit written:'
  end

  def test_a_stale_report_does_not_turn_a_startup_failure_into_offenses
    script = ruby_scripts.first
    native = "mkdir -p .tools/lint/ruby/results\nprintf 'stale report' > .tools/lint/ruby/results/rubocop-report.xml\n"
    output, errors, status = shell("#{native}bundle() { return 1; }\n#{script}")
    assert_unconfirmed_failure(output, errors, status)
    refute_path_exists File.join(@project, '.tools/lint/ruby/results/rubocop-report.xml')
  end
end
