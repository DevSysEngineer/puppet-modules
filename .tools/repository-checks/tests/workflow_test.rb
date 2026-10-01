# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require 'yaml'

# Guard the checked-in CI status boundaries without pretending to execute GitHub's UI locally.
class ToolingWorkflowTest < Minitest::Test
  ROOT = File.expand_path('../../..', __dir__)

  def test_six_independent_jobs_use_the_same_setup_after_checkout
    workflow = YAML.load_file(File.join(ROOT, '.github/workflows/checks.yml'))
    jobs = workflow.fetch('jobs')
    assert_equal ['Metadata', 'Puppet dependencies', 'Puppet lint', 'Ruby lint', 'Tool tests', 'Validate'],
                 jobs.values.map { |job| job.fetch('name') }.sort
    jobs.each_value { |job| assert_job_setup(job) }
    assert_equal 'true', workflow.dig('env', 'BUNDLE_FROZEN')
    assert_equal({ 'contents' => 'read' }, workflow.fetch('permissions'))
  end

  def assert_job_setup(job)
    refute job.key?('needs')
    steps = job.fetch('steps')
    assert_equal 'actions/checkout@v7', steps.first.fetch('uses')
    assert_equal './.github/actions/setup-tooling', steps[1].fetch('uses')
    refute(steps.any? { |step| step.key?('continue-on-error') })
  end

  def test_test_job_explicitly_requests_the_published_reports
    workflow = YAML.load_file(File.join(ROOT, '.github/workflows/checks.yml'))
    steps = workflow.fetch('jobs').fetch('tool_tests').fetch('steps')
    test_step = steps.find { |step| step['run'] == 'bundle exec rake test' }
    reports = test_step.fetch('env').fetch('MINITEST_REPORTERS_REPORTS_DIR')
    refute_empty reports
    upload, summary = reporting_steps(steps)
    assert_equal "#{reports}/TEST-*.xml", upload.dig('with', 'path')
    assert_equal "#{reports}/TEST-*.xml", summary.dig('with', 'paths')
  end

  def test_dependency_artifact_and_summary_use_the_same_report_on_failure
    steps = dependency_steps
    upload, summary = reporting_steps(steps)
    assert_equal '${{ !cancelled() }}', upload.fetch('if')
    assert_equal 'error', upload.dig('with', 'if-no-files-found')
    assert_equal upload.dig('with', 'path'), summary.dig('with', 'paths')
    assert_equal 'fail', summary.dig('with', 'show')
    assert_equal false, summary.dig('with', 'folded')
  end

  def dependency_steps
    workflow = YAML.load_file(File.join(ROOT, '.github/workflows/checks.yml'))
    workflow.fetch('jobs').fetch('puppet_dependencies').fetch('steps')
  end

  def reporting_steps(steps)
    ['actions/upload-artifact@', 'test-summary/'].map do |prefix|
      steps.find { |step| step.fetch('uses', '').start_with?(prefix) }
    end
  end

  def test_composite_action_keeps_existing_installation_choices
    action = YAML.load_file(File.join(ROOT, '.github/actions/setup-tooling/action.yml'))
    assert_equal 'composite', action.dig('runs', 'using')
    steps = action.dig('runs', 'steps')
    assert_equal 'ruby/setup-ruby@v1', steps[0].fetch('uses')
    assert_equal({ 'ruby-version' => 'ruby', 'bundler' => 'none' }, steps[0].fetch('with'))
    assert_installation_steps(steps.drop(1))
  end

  def assert_installation_steps(steps)
    assert_equal(['gem install bundler', 'bundle install'], steps.map { |step| step.fetch('run') })
    assert(steps.all? { |step| step.fetch('shell') == 'bash' })
  end
end
