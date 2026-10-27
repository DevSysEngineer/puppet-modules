# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require 'yaml'
require_relative 'ci/phase_support'

# Guard the checked-in CI status boundaries without pretending to execute GitHub's UI locally.
class ToolingPhaseWorkflowTest < Minitest::Test
  include CiPhaseSupport

  ROOT = File.expand_path('../../..', __dir__)

  PHASES = [
    ['puppet_secrets', 'Puppet secrets', []],
    ['puppet_metadata', 'Puppet metadata', ['puppet_secrets']],
    ['puppet_syntax', 'Puppet syntax', ['puppet_secrets']],
    ['puppet_dependencies', 'Puppet dependencies', %w[puppet_metadata puppet_syntax]],
    ['puppet_lint', 'Puppet lint', %w[puppet_metadata puppet_syntax]],
    ['ruby_lint', 'Ruby lint', %w[puppet_metadata puppet_syntax]],
    ['tool_tests', 'Tool tests', %w[puppet_dependencies puppet_lint ruby_lint]],
    ['puppet_catalog', 'Puppet catalogs', ['tool_tests']]
  ].freeze

  def source
    File.read(File.join(ROOT, '.github/workflows/checks.yml'))
  end

  def test_eight_jobs_use_the_same_setup_and_five_quality_phases
    workflow = YAML.safe_load(source)
    jobs = workflow.fetch('jobs')
    assert_phase_graph(jobs, PHASES, source: source)
    jobs.each_value { |job| assert_setup(job.fetch('steps')) }
    assert_equal 'true', workflow.dig('env', 'BUNDLE_FROZEN')
    assert_equal({ 'contents' => 'read' }, workflow.fetch('permissions'))
  end

  def assert_setup(steps)
    assert_equal 'actions/checkout@v7', steps.first.fetch('uses')
    assert_equal 'recursive', steps.first.dig('with', 'submodules')
    assert_equal false, steps.first.dig('with', 'persist-credentials')
    assert_equal './.github/actions/setup-tooling', steps[1].fetch('uses')
  end

  def test_every_required_edge_and_job_failure_boundary_is_enforced
    jobs = YAML.safe_load(source).fetch('jobs')
    assert_missing_edges_rejected(jobs, PHASES, source: source)
    assert_job_bypasses_rejected(jobs, PHASES, source: source)
  end

  def test_all_lower_phases_are_transitive_prerequisites
    jobs = YAML.safe_load(source).fetch('jobs')
    %w[puppet_metadata puppet_syntax].each do |predecessor|
      PHASES.drop(3).each { |id,| assert_includes ancestors(jobs, id), predecessor }
    end
    %w[puppet_dependencies puppet_lint ruby_lint].each do |predecessor|
      %w[tool_tests puppet_catalog].each { |id| assert_includes ancestors(jobs, id), predecessor }
    end
  end

  def runs_by_job
    YAML.safe_load(source).fetch('jobs').transform_values do |job|
      job.fetch('steps').filter_map { |step| step['run'] }.join("\n")
    end
  end

  def test_only_the_first_job_invokes_the_project_scan
    runs = runs_by_job
    scan_jobs = runs.keys.select { |id| runs.fetch(id).include?('rake secrets:puppet') }
    assert_equal ['puppet_secrets'], scan_jobs
    text = runs.values.join("\n")
    assert_equal 1, text.scan('rake secrets:puppet').size
    refute_match(/rake test(?:\s|$)/, text)
    refute_includes text, 'catalog:secrets'
  end
end
