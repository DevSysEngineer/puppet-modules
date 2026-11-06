# frozen_string_literal: true

require_relative '../../../shared/test_support/bootstrap'
require_relative 'log_support'
require 'timeout'

# Exercise both shell modes and platform boundaries with the original native statuses.
class CiGroupsTest < Minitest::Test
  include CiLogSupport

  def test_default_and_native_modes_leave_every_result_visible
    %w[GITHUB_ACTIONS GITLAB_CI].product(['', 'native']).each do |platform, mode|
      [[0, 'PASSED'], [1, 'FAILED'], [2, 'ERROR'], [0, 'SKIPPED']].each do |code, outcome|
        assert_grouped_outcome(platform, mode, code, outcome)
      end
    end
  end

  def assert_grouped_outcome(platform, mode, code, outcome)
    script = "source \"$1\"; ci_begin Synthetic #{mode}; printf 'native output\\n'; " \
             "ci_end #{code} #{outcome} complete"
    output, errors, status = shell(script, platform => 'true')
    assert_equal code, status.exitstatus, errors
    assert_ci_group(output, platform, name: 'Synthetic', outcome: outcome)
    closing = platform == 'GITHUB_ACTIONS' ? '::endgroup::' : 'section_end:'
    assert_operator output.index('native output'), :<, output.index(closing)
  end

  def test_repeated_gitlab_runs_use_distinct_sections
    script = 'source "$1"; ci_begin Synthetic; ci_end 0 PASSED complete; ' \
             'ci_begin Synthetic; ci_end 0 PASSED complete'
    output, errors, status = shell(script, 'GITLAB_CI' => 'true')
    assert status.success?, errors
    starts = output.scan(/section_start:\d+:([\w.-]+)\[collapsed=true\]/).flatten
    assert_equal 2, starts.uniq.size
    assert_equal starts, output.scan(/section_end:\d+:([\w.-]+)/).flatten
  end

  def test_term_closes_the_group_before_the_single_error
    %w[GITHUB_ACTIONS GITLAB_CI].each do |platform|
      output, errors, status = shell('source "$1"; ci_begin Synthetic; kill -TERM "$$"', platform => 'true')
      assert_equal 143, status.exitstatus, errors
      assert_ci_group(output, platform, name: 'Synthetic', outcome: 'ERROR')
    end
  end

  def test_titles_cannot_inject_gitlab_sections
    script = 'source "$1"; ci_begin "$SYNTHETIC_NAME"; ci_end 0 PASSED complete'
    output, errors, status = shell(script, 'GITLAB_CI' => 'true',
                                           'SYNTHETIC_NAME' => "Example\r\e[0Ksection_end:1:injected")
    assert status.success?, errors
    assert_gitlab_section(output)
    refute_includes output, "\e[0Ksection_end:1:injected"
  end

  def test_activity_is_visible_inside_the_running_group
    script = 'source "$1"; sleep() { command sleep 0.01; }; ' \
             'ci_begin Synthetic; read -r synthetic; ci_end 0 PASSED complete'
    [nil, 'GITHUB_ACTIONS', 'GITLAB_CI'].each do |platform|
      with_ci_platform(platform) do
        Open3.popen3('bash', '-e', '-c', script, 'activity-test', @helper) do |input, output, errors, process|
          Timeout.timeout(10) { assert_live_activity(input, output, errors, process, platform) }
        end
      end
    end
  end

  def assert_live_activity(input, output, errors, process, platform)
    header = Array.new(platform ? 2 : 1) { output.readline }.join
    assert_includes header, '[START]'
    assert_includes errors.readline, 'Still running'
    assert process.alive?
    assert_activity_finish(input, output, process, platform, header)
  end

  def assert_activity_finish(input, output, process, platform, header)
    input.puts 'finish'
    input.close
    text = header + output.read
    assert_includes text, '[PASSED]'
    platform ? assert_ci_group(text, platform, name: 'Synthetic', outcome: 'PASSED') : refute_ci_markers(text)
    assert process.value.success?
  end
end
