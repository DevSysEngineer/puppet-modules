# frozen_string_literal: true

require_relative '../../../shared/test_support/bootstrap'
require_relative '../../../shared/test_support/packages'
require_relative 'task_support'
require 'yaml'

# Apply needs-success semantics to a real rejected scan in an isolated project.
class CiGatePhasesTest < Minitest::Test
  include CiTaskSupport

  def test_rejected_and_incomplete_scans_release_no_later_phase
    ["notify { 'fixture': message => Sensitive('synthetic-value') }\n", 'class {'].each do |manifest|
      write('modules/sample/manifests/init.pp', manifest)
      write('events', '')
      assert_equal({ 'puppet_secrets' => false }, released_jobs)
      assert_includes [1, 2], @status.exitstatus
      assert_equal ['scan'], events
      refute_path_exists File.join(@project, '.tools/catalog/results/catalog-report.xml')
    end
  end

  def released_jobs
    jobs = YAML.load_file(File.join(ROOT, '.github/workflows/checks.yml')).fetch('jobs')
    jobs.each_with_object({}) do |(id, job), outcomes|
      next unless job.fetch('needs', []).all? { |parent| outcomes[parent] }

      outcomes[id] = id == jobs.keys.first ? scan_passes?(job) : true
    end
  end

  def scan_passes?(job)
    command = job.fetch('steps').filter_map { |step| step['run'] }.find { |run| run.start_with?('bundle exec rake ') }
    invoke(command.delete_prefix('bundle exec rake '))
    @status.success?
  end
end
