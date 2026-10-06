# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative 'ci_log_support'
require 'yaml'

# Preserve the native command and status boundaries of the checked-in workflow.
class CiNativeStepsTest < Minitest::Test
  include CiLogSupport

  def workflow_steps(job)
    YAML.load_file(File.join(ROOT, '.github/workflows/checks.yml')).fetch('jobs').fetch(job).fetch('steps')
  end

  def test_pipeline_retains_scan_and_converter_status_and_rightmost_failure_priority
    step = workflow_steps('puppet_lint').find { |item| item.fetch('run', '').include?('PIPESTATUS') }
    script = step.fetch('run').sub('source .github/actions/setup-tooling/log.sh', 'source "$1"')
    [[0, 0, 0], [1, 0, 1], [0, 3, 3], [7, 3, 3]].each do |scan, converter, expected|
      assert_pipeline(script, scan, converter, expected)
    end
  end

  def assert_pipeline(script, scan, converter, expected)
    output, errors, status = shell(fake_pipeline + script, 'SCAN_STATUS' => scan.to_s,
                                                           'CONVERTER_STATUS' => converter.to_s)
    assert_equal expected, status.exitstatus, output + errors
    assert_includes output, "Native scan exit status: #{scan} | Converter exit status: #{converter}"
    assert_includes errors, 'native warning'
    refute_includes output, '[PASSED]' unless expected.zero?
  end

  def fake_pipeline
    <<~BASH
      bundle() {
          if [ "$2" = puppet-lint ]; then
              printf '[[], []]'
              printf 'native warning\n' >&2
              return "$SCAN_STATUS"
          fi
          local input
          input=$(cat)
          [ "$input" = '[[], []]' ] || return 99
          return "$CONVERTER_STATUS"
      }
    BASH
  end

  def test_checkout_failure_is_a_separate_failed_control_after_success
    step = workflow_steps('metadata').find { |item| item['name'] == 'Check for changes' }
    script = step.fetch('run').sub('source .github/actions/setup-tooling/log.sh', 'source "$1"')
    native = "printf '[PASSED] Metadata\n'\ngit() { printf 'synthetic diff\n'; return 1; }\n"
    output, _errors, status = shell(native + script)
    assert_equal 1, status.exitstatus
    assert_includes output, '[PASSED] Metadata'
    assert_includes output, '[FAILED] Checkout changes'
    assert_includes output, 'synthetic diff'
  end

  def test_installation_failure_reports_without_an_installed_bundle
    script = "gem() { printf 'synthetic installation error\n' >&2; return 23; }\n#{bundler_step}"
    output, errors, status = shell(script, 'GITHUB_ACTION_PATH' => File.dirname(@helper), 'GITHUB_ACTIONS' => 'true')
    assert_equal 23, status.exitstatus
    assert_includes errors, 'synthetic installation error'
    assert_includes output, '[ERROR] Install Bundler'
    assert_operator output.index('::endgroup::'), :<, output.index('[ERROR]')
  end

  def bundler_step
    action = YAML.load_file(File.join(ROOT, '.github/actions/setup-tooling/action.yml'))
    action.dig('runs', 'steps').find { |item| item.fetch('run', '').include?('gem install bundler') }.fetch('run')
  end

  def test_rubocop_offenses_and_runtime_errors_keep_distinct_outcomes
    step = workflow_steps('ruby_lint').find { |item| item.fetch('run', '').include?('bundle exec rubocop') }
    script = step.fetch('run').sub('source .github/actions/setup-tooling/log.sh', 'source "$1"')
    { 0 => 'PASSED', 1 => 'FAILED', 2 => 'ERROR' }.each do |code, outcome|
      output, errors, status = shell("bundle() { printf 'native diagnostic\n' >&2; return #{code}; }\n#{script}")
      assert_equal code, status.exitstatus
      assert_includes output, "[#{outcome}] Ruby lint"
      assert_includes errors, 'native diagnostic'
    end
  end
end
