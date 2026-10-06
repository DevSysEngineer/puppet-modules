# frozen_string_literal: true

require_relative 'test_helper'
require 'project_tools/validate'
require 'rexml/document'
require 'stringio'

# Selection and report failures must not produce a passing or stale validation report.
class ValidateTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('validate-')
  end

  def write_file(relative, content)
    write(relative, content)
    File.join(@project, relative)
  end

  def run_report(*paths)
    @report = File.join(@project, 'results', 'puppet.xml')
    @console = StringIO.new
    @errors = StringIO.new
    @result = ProjectTools::Validate.run([@report, *paths], console: @console, errors: @errors)
    REXML::Document.new(File.read(@report)).root.elements['testsuite']
  end

  def test_empty_selection_creates_an_error_report_and_replaces_previous_results
    write_file('results/puppet.xml', '<stale-passing-report/>')
    suite = run_report
    assert_equal 1, @result
    assert_equal '1', suite.attributes['errors']
    assert_equal 'No Puppet manifests selected.', suite.elements['testcase/error'].text
    assert_includes @console.string, 'No Puppet manifests selected.'
    refute_includes File.read(@report), 'stale-passing-report'
  end

  def test_missing_files_directories_and_other_formats_are_errors
    other = write_file('other.txt', '$value = 1')
    suite = run_report(File.join(@project, 'missing.pp'), @project, other)
    assert_equal 1, @result
    assert_equal '3', suite.attributes['tests']
    assert_equal '3', suite.attributes['errors']
    assert_equal '0', suite.attributes['failures']
    assert_equal 3, suite.get_elements('testcase/error').length
  end

  def test_equivalent_paths_are_validated_once_and_create_the_report_directory
    path = write_file('manifest with spaces & é.pp', '$value = "synthetic"')
    suite = run_report(path, File.join(@project, '.', File.basename(path)))
    assert_equal 0, @result, @console.string
    assert_equal(%w[1 0 0], %w[tests failures errors].map { |key| suite.attributes[key] })
    assert_includes suite.elements['testcase'].attributes['file'], 'manifest with spaces & é.pp'
  end

  def test_usage_errors_fail_without_modifying_manifests
    path = write_file('site.pp', '$value = 1')
    [[], [path]].each do |arguments|
      errors = StringIO.new
      assert_equal 1, ProjectTools::Validate.run(arguments, console: StringIO.new, errors: errors)
      assert_equal "Usage: validate-junit REPORT.xml MANIFEST.pp [MANIFEST.pp ...]\n", errors.string
    end
    assert_equal '$value = 1', File.read(path)
  end

  def test_output_errors_fail_without_modifying_manifests
    path = write_file('site.pp', '$value = 1')
    errors = StringIO.new
    assert_equal 1, ProjectTools::Validate.run([File.join(path, 'report.xml'), path],
                                               console: StringIO.new, errors: errors)
    assert_includes errors.string, 'Cannot write'
    assert_equal '$value = 1', File.read(path)
  end

  def test_results_are_visible_before_the_next_manifest_and_survive_report_failure
    console = StringIO.new
    errors = StringIO.new
    validator = failing_writer(console)
    assert_equal 1, validator.run(File.join(@project, 'report.xml'), errors)
    assert_includes console.string, '[ERROR] Puppet validation'
    assert_includes console.string, 'Results: 2 failures'
    assert_includes console.string, 'second diagnostic'
    assert_includes errors.string, 'synthetic report failure'
    refute_includes console.string, 'JUnit written:'
  end

  def failing_writer(console)
    validator = ProjectTools::Validate.new(%w[first.pp second.pp], console)
    validator.define_singleton_method(:validate) do |path|
      raise 'first result was buffered' if path == 'second.pp' && !console.string.include?('first diagnostic')

      { path: path, kind: :failure, message: path == 'first.pp' ? 'first diagnostic' : 'second diagnostic' }
    end
    validator.define_singleton_method(:write_case) { |_xml, _result| raise IOError, 'synthetic report failure' }
    validator
  end

  def test_native_warning_keeps_success_and_report_details
    console = StringIO.new
    validator = ProjectTools::Validate.new(['warning.pp'], console)
    validator.define_singleton_method(:validate) do |path|
      { path: path, kind: nil, message: 'Warning: synthetic native warning' }
    end
    report = File.join(@project, 'warning.xml')
    assert_equal 0, validator.run(report, StringIO.new)
    assert_includes console.string, '[PASSED] Puppet validation'
    assert_includes console.string, 'Warning: synthetic native warning'
    assert_includes File.read(report), '<system-out>Warning: synthetic native warning</system-out>'
  end
end
