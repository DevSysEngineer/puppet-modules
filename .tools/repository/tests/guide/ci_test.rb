# frozen_string_literal: true

require_relative '../../../shared/test_support/bootstrap'
require 'yaml'

# Validate the independent job and artifact contracts in both documented CI configurations.
class GuideCiTest < Minitest::Test
  ROOT = File.expand_path('../../../..', __dir__)

  def guide
    File.read(File.join(ROOT, '.tools/README.md'))
  end

  def test_ci_examples_keep_independent_checks_and_failure_artifacts
    github = configuration_with('jobs')
    gitlab = configuration_with('.check_setup')
    assert_equal 'bash', github.dig('defaults', 'run', 'shell')
    assert_includes gitlab.dig('.check_setup', 'before_script'), 'set -eo pipefail'
    %w[syntax puppet_lint ruby_lint tool_tests puppet_dependencies metadata].each do |name|
      assert_github_job(github.fetch('jobs').fetch(name))
      assert_gitlab_job(gitlab.fetch(name))
    end
  end

  def configuration_with(key)
    configurations = guide.scan(/^```yaml\n(.*?)^```/m).flatten.map { |text| YAML.safe_load(text) }
    config = configurations.find { |item| item.is_a?(Hash) && item.key?(key) }
    refute_nil config
    config
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

  def command_contracts
    { 'syntax' => /bundle exec (?:syntax-junit|rake syntax:puppet)/,
      'puppet_lint' => /bundle exec puppet-lint-junit/,
      'ruby_lint' => /bundle exec rubocop --config .rubocop.yml/,
      'tool_tests' => /bundle exec rake test/,
      'metadata' => /bundle exec project-tools-metadata --junit /,
      'puppet_dependencies' => /bundle exec project-tools-module --junit / }
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

  def assert_secret_stages
    assert_equal %w[secrets checks], configuration_with('.check_setup').fetch('stages')
  end

  def test_ci_examples_request_test_reports_explicitly
    github = configuration_with('jobs').fetch('jobs').fetch('tool_tests')
    step = github.fetch('steps').find { |item| item.fetch('run', '').include?('bundle exec rake test') }
    assert_equal '${{ env.PROJECT_REPORT_DIR }}', step.dig('env', 'MINITEST_REPORTERS_REPORTS_DIR')
    gitlab = configuration_with('.check_setup').fetch('tool_tests')
    assert_includes gitlab.fetch('script').join("\n"),
                    'MINITEST_REPORTERS_REPORTS_DIR="$PROJECT_REPORT_DIR" bundle exec rake test'
  end

  def assert_github_job(job)
    assert_equal 'puppet_secrets', job.fetch('needs')
    steps = job.fetch('steps')
    assert(steps.any? { |step| step.fetch('run', '').include?('if git diff --quiet HEAD --; then') })
    refute(steps.any? { |step| step.fetch('run', '').include?('--fix') })
    uploads = steps.select { |step| step.fetch('uses', '').start_with?('actions/upload-artifact@') }
    assert_github_uploads(uploads)
  end

  def assert_github_uploads(uploads)
    assert_equal 1, uploads.size
    upload = uploads.first
    assert_equal '${{ !cancelled() }}', upload.fetch('if')
    assert upload.dig('with', 'include-hidden-files')
    assert_match(%r{\A\$\{\{ env.PROJECT_REPORT_DIR \}\}/(?:[\w-]+|TEST-\*)\.xml\z},
                 upload.dig('with', 'path'))
  end

  def assert_gitlab_job(job)
    refute job.key?('needs')
    assert_equal '.check_setup', job.fetch('extends')
    assert_includes job.fetch('script').last, 'if git diff --quiet HEAD --; then'
    refute(job.fetch('script').any? { |command| command.include?('--fix') })
    assert_equal 'always', job.dig('artifacts', 'when')
    assert_equal [job.dig('artifacts', 'reports', 'junit')], job.dig('artifacts', 'paths')
  end

  def test_documented_ci_shell_blocks_are_valid_bash
    ci_scripts.each do |script|
      output, errors, status = Open3.capture3('bash', '-n', stdin_data: script)
      assert status.success?, output + errors
    end
  end

  def ci_scripts
    gitlab = configuration_with('.check_setup')
    github_scripts + gitlab.dig('.check_setup', 'before_script') +
      command_contracts.keys.flat_map { |job| gitlab.fetch(job).fetch('script') }
  end

  def github_scripts
    steps = configuration_with('jobs').fetch('jobs').values.flat_map { |job| job.fetch('steps') }
    steps.filter_map { |step| step['run'] }
  end
end
