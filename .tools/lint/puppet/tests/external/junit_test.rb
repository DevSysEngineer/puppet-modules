# frozen_string_literal: true

require_relative '../test_helper'
require_relative 'installed_gem_support'
require 'rexml/document'

# The packaged converter consumes one native scan without replacing its configuration or status.
class ExternalJunitTest < Minitest::Test
  include InstalledGemSupport

  def test_installed_help_does_not_consume_input_or_replace_a_report
    write('puppet.xml', '<previous/>')
    %w[-h --help].each do |flag|
      run_success('bundle', 'exec', 'puppet-lint-junit', '--result-status', 'puppet.xml', flag)
      assert_match(/\AUsage:/, @output)
      assert_empty @errors
      assert_equal '<previous/>', read('puppet.xml')
    end
  end

  def test_installed_converter_rejects_unknown_options_without_creating_a_report
    command('bundle', 'exec', 'puppet-lint-junit', '--unknown-option')
    assert_equal 1, @status.exitstatus
    assert_includes @errors, 'Usage:'
    refute_path_exists File.join(@project, '--unknown-option')
  end

  def test_clean_and_failed_native_scans_keep_their_status
    @env['GITHUB_ACTION'] = 'synthetic_test'
    junit_pipeline
    assert @status.success?, @output + @errors
    assert_includes read('puppet.xml'), 'name="Puppet lint scan"'
    code = "$values = [1] + [2]\n$other = [3] + [4]\n"
    write('manifests/site.pp', code)
    junit_pipeline
    assert_findings_report
    assert_equal code, read('manifests/site.pp')
  end

  def assert_findings_report
    refute @status.success?
    report = read('puppet.xml')
    suite = REXML::Document.new(report).root.elements['testsuite']
    assert_equal '1', suite.attributes['failures']
    assert_includes report, 'name="manifests/site.pp:project_arrays"'
    assert_includes report, 'manifests/site.pp:2:'
    assert_includes @output, 'project_arrays: warning:'
  end

  def test_native_startup_failure_produces_a_report_error
    write('.puppet-lint.rc', "--invalid-consumer-option\n")
    junit_pipeline
    refute @status.success?
    assert_includes read('puppet.xml'), '<error type="ReportError">'
  end

  def junit_pipeline(result_status: false)
    converter = result_status ? 'puppet-lint-junit --result-status' : 'puppet-lint-junit'
    script = 'bundle exec puppet-lint --no-config --load "$1/lib/project_lint.rb" ' \
             '--config "$1/config/puppet-lint.rc" --config .puppet-lint.rc --json manifests ' \
             "| bundle exec #{converter} puppet.xml"
    command('bash', '-o', 'pipefail', '-c', script, 'junit-test', @installed)
  end

  def test_installed_converter_exposes_findings_separately_from_conversion_errors
    write('manifests/site.pp', "$values = [1] + [2]\n")
    junit_pipeline(result_status: true)
    assert_equal 10, @status.exitstatus, @output + @errors
    assert_includes read('puppet.xml'), '<failure'

    write('.puppet-lint.rc', "--invalid-consumer-option\n")
    junit_pipeline(result_status: true)
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes read('puppet.xml'), '<error type="ReportError">'
  end

  def test_converter_failure_remains_a_pipeline_failure
    FileUtils.mkdir_p(File.join(@project, 'puppet.xml'))
    junit_pipeline
    assert_equal 1, @status.exitstatus
    assert_includes @errors, 'Cannot write Puppet-lint JUnit report'
  end

  def test_invalid_manifest_retains_error_status_and_parseable_report
    write('manifests/site.pp', "class broken (String $value = ) {}\n")
    junit_pipeline
    assert_equal 1, @status.exitstatus
    suite = REXML::Document.new(read('puppet.xml')).root.elements['testsuite']
    assert_operator suite.attributes['failures'].to_i, :>, 0
    assert suite.elements['testcase/failure']
  end
end
