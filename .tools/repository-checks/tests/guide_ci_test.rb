# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require 'yaml'

# Validate the independent job and artifact contracts in both documented CI configurations.
class GuideCiTest < Minitest::Test
  ROOT = File.expand_path('../../..', __dir__)

  def guide
    File.read(File.join(ROOT, '.tools/README.md'))
  end

  def test_ci_examples_keep_independent_checks_and_failure_artifacts
    github = configuration_with('jobs')
    gitlab = configuration_with('.check_setup')
    assert_equal 'bash', github.dig('defaults', 'run', 'shell')
    assert_includes gitlab.dig('.check_setup', 'before_script'), 'set -eo pipefail'
    %w[validate puppet_lint ruby_lint tool_tests puppet_dependencies metadata].each do |name|
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
    { 'validate' => /bundle exec (?:validate-junit|rake validate:puppet)/,
      'puppet_lint' => /bundle exec puppet-lint-junit/,
      'ruby_lint' => /bundle exec rubocop --config .rubocop.yml/,
      'tool_tests' => /bundle exec rake test/,
      'metadata' => /bundle exec project-tools-metadata --junit /,
      'puppet_dependencies' => /bundle exec project-tools-module-dependencies --junit / }
  end

  def test_ci_examples_request_test_reports_explicitly
    github = configuration_with('jobs').fetch('jobs').fetch('tool_tests')
    step = github.fetch('steps').find { |item| item['run'] == 'bundle exec rake test' }
    assert_equal '${{ env.PROJECT_REPORT_DIR }}', step.dig('env', 'MINITEST_REPORTERS_REPORTS_DIR')
    gitlab = configuration_with('.check_setup').fetch('tool_tests')
    assert_includes gitlab.fetch('script'),
                    'MINITEST_REPORTERS_REPORTS_DIR="$PROJECT_REPORT_DIR" bundle exec rake test'
  end

  def assert_github_job(job)
    refute job.key?('needs')
    steps = job.fetch('steps')
    assert(steps.any? { |step| step['run'] == 'git diff --exit-code HEAD --' })
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
    assert_equal 'git diff --exit-code HEAD --', job.fetch('script').last
    refute(job.fetch('script').any? { |command| command.include?('--fix') })
    assert_equal 'always', job.dig('artifacts', 'when')
    assert_equal [job.dig('artifacts', 'reports', 'junit')], job.dig('artifacts', 'paths')
  end
end
