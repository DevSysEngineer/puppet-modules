# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

# Preserve report provenance, error precedence and safe presentation of untrusted fields.
class DependencyReportTest < Minitest::Test
  include DependencyTestSupport

  def test_new_input_failure_replaces_old_success_and_preserves_other_reports
    write_module('library')
    scan(0)
    other = File.join(@project, 'reports/another.xml')
    File.write(other, 'keep this report')
    @env['PROJECT_TOOLS_MODULEPATH'] = nil
    scan(2)
    assert_equal '1', @suite.attributes['errors']
    assert_equal 'keep this report', File.read(other)
  end

  def test_extra_arguments_replace_a_previous_success_when_the_report_is_known
    write_module('library')
    scan(0)
    _, _, status = Open3.capture3(@env, RbConfig.ruby, dependency_executable,
                                  '--junit', @report, 'unexpected', chdir: @project)
    assert_equal 2, status.exitstatus
    suite = read_suite
    assert_equal '1', suite.attributes['errors']
    assert_includes suite.elements['testcase/error'].text, 'Usage:'
  end

  def test_unwritable_report_destination_returns_two
    write_module('library')
    File.write(File.join(@project, 'blocker'), 'ordinary file')
    @report = File.join(@project, 'blocker/report.xml')
    output, errors, status = Open3.capture3(@env, RbConfig.ruby,
                                            dependency_executable,
                                            '--junit', @report, chdir: @project)
    assert_equal 2, status.exitstatus
    assert_includes errors, 'Cannot write'
    refute_includes output, 'PASSED'
  end

  def test_xml_escaping_and_terminal_workflow_command_safety
    requirement = "< 3 & \"quoted\"\n::error::synthetic\e[31m"
    write_module('library')
    write_root([dependency('example-library', requirement)])
    scan(1)
    assert_equal 'non_semantic_version', junit_failures.first.attributes['type']
    assert_safe_console
    assert_includes @suite.elements['testcase'].attributes['name'], '< 3 & "quoted"'
  end

  def assert_safe_console
    refute_match(/^::error::/, @output + @errors)
    refute_includes @output + @errors, "\e"
  end

  def test_errors_take_precedence_without_discarding_trusted_conflicts
    write_module('consumer', dependencies: [dependency('example-missing')])
    File.unlink(File.join(@project, 'metadata.json'))
    scan(2)
    assert_equal 1, junit_failures.length
    assert_equal 1, junit_errors.length
    assert_equal '2', @suite.attributes['tests']
  end

  def test_report_contains_incomplete_error_before_native_runtime_failure
    _, _, status = Open3.capture3(RbConfig.ruby, '-e', interrupted_scan, chdir: @project)
    refute status.success?
    assert_includes File.read(@report), 'incomplete_scan'
  end

  def interrupted_scan
    <<~RUBY
      require 'project_tools/module_dependencies/cli'
      class ProjectTools::ModuleDependencies::Cli
        def scan
          report = File.read(#{@report.dump})
          abort 'missing incomplete marker' unless report.include?('incomplete_scan')
          raise Interrupt
        end
      end
      ProjectTools::ModuleDependencies::Cli.run(['--junit', #{@report.dump}])
    RUBY
  end
end
