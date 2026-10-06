# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'
require 'rexml/document'

# Exercise the parser task's selection and report opt-in using synthetic manifests only.
class ParserRakeReportingTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('parser-rake-reporting-')
    write('Rakefile', rakefile)
    write('modules/profile/manifests/init.pp', "class profile {}\n")
  end

  def rakefile
    File.read(File.join(ROOT, 'Rakefile'))
  end

  def excluded_directories
    %w[.tools vendor concat debconf reboot stdlib]
  end

  def run_parser(report = nil)
    task = report ? "validate:puppet[#{report}]" : 'validate:puppet'
    @output, @errors, @status = Open3.capture3(
      { 'PROJECT_REPORT_DIR' => 'unused reports' },
      RbConfig.ruby, Gem.bin_path('rake', 'rake'), task, chdir: @project
    )
  end

  def tree
    Dir.glob('**/*', File::FNM_DOTMATCH, base: @project)
  end

  def suite
    REXML::Document.new(read('reports with spaces/validate.xml')).root.elements['testsuite']
  end

  def test_console_only_does_not_create_or_update_reports
    before = tree
    run_parser
    assert @status.success?, @output + @errors
    assert_equal before, tree
    write('.tools/validate/results/validate-report.xml', '<previous/>')
    run_parser
    assert @status.success?, @output + @errors
    assert_equal '<previous/>', read('.tools/validate/results/validate-report.xml')
    refute_path_exists File.join(@project, 'unused reports')
  end

  def test_success_and_manifest_selection_match_with_and_without_reports
    excluded_directories.each { |path| write("#{path}/invalid.pp", "class {\n") }
    write('examples/path with spaces.pp', "notice('synthetic example')\n")
    [nil, 'reports with spaces/validate.xml'].each do |report|
      run_parser(report)
      assert @status.success?, @output + @errors
    end
    assert_report_selection('examples/path with spaces.pp', 'modules/profile/manifests/init.pp')
    assert_equal '0', suite.attributes['failures']
  end

  def assert_report_selection(*paths)
    assert_equal paths.sort, suite.get_elements('testcase').map { |entry| entry.attributes['name'] }.sort
  end

  def test_syntax_failures_keep_their_status_in_both_modes
    write('modules/profile/manifests/init.pp', "class profile {\n")
    write('examples/broken.pp', "class broken {\n")
    [nil, 'reports with spaces/validate.xml'].each do |report|
      run_parser(report)
      assert_equal 1, @status.exitstatus, @output + @errors
      assert_includes @output + @errors, 'Syntax error'
      refute_includes @errors, 'rake aborted!'
    end
    assert_equal '2', suite.attributes['failures']
    assert_equal "class profile {\n", read('modules/profile/manifests/init.pp')
  end

  def test_empty_selection_fails_in_both_modes
    FileUtils.rm_r(File.join(@project, 'modules'))
    [nil, 'reports with spaces/validate.xml'].each do |report|
      run_parser(report)
      assert_equal 1, @status.exitstatus, @output + @errors
      assert_includes @output + @errors, 'No Puppet manifests selected.'
    end
    assert_equal '1', suite.attributes['errors']
  end

  def test_requested_unwritable_report_fails
    write('blocker', 'ordinary file')
    run_parser('blocker/validate.xml')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @errors, 'Cannot write Puppet validation JUnit report'
    assert_equal 'ordinary file', read('blocker')
  end
end
