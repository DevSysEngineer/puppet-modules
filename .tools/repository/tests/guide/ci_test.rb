# frozen_string_literal: true

require_relative '../../../shared/test_support/bootstrap'
require 'yaml'
require_relative '../ci/phase_support'
require_relative 'ci_support'

# Validate the phase and artifact contracts in both documented CI configurations.
class GuideCiTest < Minitest::Test
  include CiPhaseSupport
  include GuideCiSupport

  def test_ci_examples_keep_independent_checks_and_failure_artifacts
    github = configuration_with('jobs')
    gitlab = configuration_with('.check_setup')
    assert_equal 'bash', github.dig('defaults', 'run', 'shell')
    assert_includes gitlab.dig('.check_setup', 'before_script'), 'set -eo pipefail'
    %w[puppet_metadata puppet_syntax puppet_dependencies puppet_lint puppet_catalog].each do |name|
      assert_github_job(github.fetch('jobs').fetch(name))
      assert_gitlab_job(gitlab.fetch(name))
    end
  end

  def test_ci_jobs_invoke_the_documented_checks_and_report_conversion
    github = configuration_with('jobs').fetch('jobs')
    gitlab = configuration_with('.check_setup')
    command_contracts.each do |job, command|
      runs = github.fetch(job).fetch('steps').filter_map { |step| step['run'] }.join("\n")
      assert_match command, runs
      assert_match command, gitlab.fetch(job).fetch('script').join("\n")
    end
  end

  def test_consumer_secret_jobs_use_the_shared_cli_before_diagnostics
    github = configuration_with('jobs').fetch('jobs').fetch('puppet_secrets')
    gitlab = configuration_with('.check_setup').fetch('puppet_secrets')
    command = 'bundle exec project-tools-secrets --puppet environments/ modules/'
    assert_includes github.fetch('steps').filter_map { |step| step['run'] }, command
    refute github.key?('needs')
    assert_equal 'secrets', gitlab.fetch('stage')
    assert_includes gitlab.fetch('script'), command
    assert_secret_stages
  end

  def test_consumer_phases_omit_inapplicable_jobs_without_losing_dependencies
    jobs = configuration_with('jobs').fetch('jobs')
    assert_phase_graph(jobs, PHASES, source: guide)
    assert_missing_edges_rejected(jobs, PHASES, source: guide)
    assert_job_bypasses_rejected(jobs, PHASES, source: guide)
    assert_gitlab_phases(configuration_with('.check_setup'))
  end

  def test_gitlab_phase_checks_reject_early_jobs_and_failure_bypasses
    config = configuration_with('.check_setup')
    PHASES.map(&:first).each do |id|
      [{ 'stage' => 'tool_tests' }, { 'needs' => [] }, { 'allow_failure' => true },
       { 'when' => 'always' }, { 'rules' => [{ 'when' => 'manual' }] }].each do |override|
        changed = Marshal.load(Marshal.dump(config))
        changed.fetch(id).merge!(override)
        assert_raises(Minitest::Assertion) { assert_gitlab_phases(changed) }
      end
    end
  end

  def test_optional_tool_tests_request_reports_via_the_focused_task
    assert_includes guide, 'MINITEST_REPORTERS_REPORTS_DIR="$PROJECT_REPORT_DIR" bundle exec rake test:tools'
    assert_includes guide, 'test-summary/action@v2'
    assert_includes guide, 'TEST-*.xml'
    assert_includes guide, 'artifacts:reports:junit'
    assert_includes guide, 'ruby_lint'
  end

  def test_consumer_routes_have_one_project_scan_and_no_protected_aggregate
    gitlab = configuration_with('.check_setup')
    scripts = [github_scripts.join("\n"), PHASES.flat_map { |id,| gitlab.fetch(id).fetch('script') }.join("\n")]
    scripts.each do |text|
      assert_equal 1, text.scan('project-tools-secrets --puppet environments/ modules/').size
      refute_match(/rake test(?:\s|$)/, text)
      refute_includes text, 'catalog:secrets'
      refute_includes text, 'global-modules/.tools/**/tests'
    end
  end

  def test_consumers_configure_their_own_metadata
    github = configuration_with('jobs')
    gitlab = configuration_with('.check_setup')
    assert_equal 'modules', github.dig('jobs', 'puppet_metadata', 'env', 'PROJECT_METADATA_MODULES_PATH')
    assert_equal 'example', gitlab.dig('puppet_metadata', 'variables', 'PROJECT_METADATA_PREFIX')
    assert_includes guide, 'eigen `VERSION`'
  end

  def test_documented_ci_shell_blocks_are_valid_bash
    ci_scripts.each do |script|
      output, errors, status = Open3.capture3('bash', '-n', stdin_data: script)
      assert status.success?, output + errors
    end
  end
end
