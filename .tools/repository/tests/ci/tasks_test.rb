# frozen_string_literal: true

require_relative '../../../shared/test_support/bootstrap'
require_relative '../../../shared/test_support/packages'
require 'rexml/document'
require 'yaml'
require_relative 'task_support'

# Load the real Rake graph in isolated projects and count only project scanner calls.
class CiTasksTest < Minitest::Test
  include ProjectToolsPackageSupport
  include CiTaskSupport

  def ci_routes
    jobs = YAML.load_file(File.join(ROOT, '.github/workflows/checks.yml')).fetch('jobs')
    commands = jobs.values.flat_map { |job| job.fetch('steps').filter_map { |step| step['run'] } }
    commands.grep(/\Abundle exec rake /).map do |command|
      command.delete_prefix('bundle exec rake ').delete("'")
    end
  end

  def test_loaded_ci_routes_scan_once_and_leave_catalog_reporting_intact
    routes = ci_routes
    assert_equal %w[secrets:puppet syntax:puppet[.tools/syntax/results/syntax-report.xml] test:tools
                    catalog:compile[.tools/catalog/results/catalog-report.xml]], routes
    routes.each { |route| invoke_route(route) }
    assert_ci_results
  end

  def invoke_route(route)
    name, argument = route.delete_suffix(']').split('[', 2)
    invoke(name, argument)
    assert @status.success?, @output + @errors
    assert_empty JSON.parse(read('prerequisites.json')) if %w[test:tools catalog:compile].include?(name)
  end

  def assert_ci_results
    assert_equal %w[scan tools], events
    assert_equal %w[examples/example.pp modules/sample/manifests/init.pp modules/sample/tests/manifests/default.pp],
                 JSON.parse(read('selection.json')).sort
    assert_catalog_report
    assert_path_exists File.join(@project, 'reports/TEST-PhaseProbe.xml')
  end

  def assert_catalog_report
    suite = REXML::Document.new(read('.tools/catalog/results/catalog-report.xml')).root.elements['testsuite']
    assert_equal 'catalog', suite.attributes['name']
    assert_equal '1', suite.attributes['tests']
    assert_equal '0', suite.attributes['failures']
  end

  def test_local_aggregate_scans_before_running_the_tools_once
    invoke('test')
    assert @status.success?, @output + @errors
    assert_equal %w[scan tools], events
    assert_equal %w[secrets:puppet test:tools].sort, JSON.parse(read('prerequisites.json')).sort
  end

  def test_rejected_and_incomplete_scans_preserve_status_and_stop_local_tests
    [1, 2].each do |code|
      write('events', '')
      invoke('test', code: code)
      assert_equal code, @status.exitstatus, @output + @errors
      assert_equal ['scan'], events
      refute_path_exists File.join(@project, 'reports/TEST-PhaseProbe.xml')
      refute_path_exists File.join(@project, '.tools/catalog/results/catalog-report.xml')
    end
  end
end
