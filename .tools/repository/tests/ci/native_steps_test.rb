# frozen_string_literal: true

require_relative '../../../shared/test_support/bootstrap'
require_relative 'log_support'
require 'yaml'

# Preserve the native command and status boundaries of the checked-in workflow.
class CiNativeStepsTest < Minitest::Test
  include CiLogSupport

  def test_pipeline_retains_scan_and_converter_status_and_rightmost_failure_priority
    puppet_scripts.each do |script|
      [[0, 0, 0, 'PASSED'], [1, 10, 1, 'FAILED'], [0, 10, 0, 'PASSED'],
       [1, 0, 1, 'ERROR'], [7, 10, 7, 'ERROR'], [1, 1, 1, 'ERROR'],
       [0, 3, 3, 'ERROR'], [7, 3, 3, 'ERROR']].each do |scan, converter, expected, outcome|
        assert_pipeline(script, scan, converter, expected, outcome)
      end
    end
  end

  def puppet_scripts
    github = guide_configuration('jobs').dig('jobs', 'puppet_lint', 'steps')
    gitlab = guide_configuration('.check_setup').dig('puppet_lint', 'script')
    scripts = [puppet_script(workflow_steps('puppet_lint')), puppet_script(github)]
    scripts << gitlab.find { |script| script.include?('PIPESTATUS') }
    scripts.map { |script| "source \"$1\"\nci_begin 'Puppet lint'\nset +e\n#{script.split("set +e\n", 2).last}" }
  end

  def puppet_script(steps)
    steps.find { |item| item.fetch('run', '').include?('PIPESTATUS') }.fetch('run')
  end

  def assert_pipeline(script, scan, converter, expected, outcome)
    output, errors, status = shell(fake_pipeline + script, 'SCAN_STATUS' => scan.to_s,
                                                           'CONVERTER_STATUS' => converter.to_s)
    assert_equal expected, status.exitstatus, output + errors
    conversion_status = converter == 10 ? 0 : converter
    assert_includes output, "Native scan exit status: #{scan} | Converter exit status: #{conversion_status}"
    assert_pipeline_outcome(output, outcome)
    assert_includes errors, 'native warning'
  end

  def assert_pipeline_outcome(output, outcome)
    assert_includes output, "[#{outcome}] Puppet lint"
    assert_includes output, 'Execution: incomplete' if outcome == 'ERROR'
    assert_includes output, '--fail-on-warnings also rejects warnings' if outcome == 'FAILED'
    refute_includes output, 'unknown'
    refute_includes output, '[PASSED]' unless outcome == 'PASSED'
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
    native = "printf '[PASSED] Metadata\n'\ngit() { [ \"$2\" = --quiet ] || printf 'synthetic diff\n'; return 1; }\n"
    output, _errors, status = shell(native + script)
    assert_equal 1, status.exitstatus
    assert_includes output, '[PASSED] Metadata'
    assert_includes output, '[FAILED] Checkout changes'
    refute_includes output, 'synthetic diff'
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
end
