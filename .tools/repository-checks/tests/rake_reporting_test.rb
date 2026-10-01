# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'
require 'rexml/document'

# Public Rake entrypoints must leave report storage optional without changing test status.
class RakeReportingTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('rake-reporting-')
    write('Rakefile', File.read(File.join(ROOT, 'Rakefile')))
    write_probe(true)
  end

  def write_probe(success, bootstrap: File.join(ROOT, '.tools/shared/test_support/bootstrap'))
    write('.tools/shared/tests/probe_test.rb', <<~RUBY)
      require #{bootstrap.dump}
      class ReportingProbe < Minitest::Test
        def test_synthetic_contract
          assert #{success}
        end
      end
    RUBY
  end

  def run_task(*tasks, reports: nil)
    environment = { 'MINITEST_REPORTERS_REPORTS_DIR' => reports, 'TEST' => nil, 'TESTOPTS' => nil }
    @output, @errors, @status = Open3.capture3(environment, RbConfig.ruby, Gem.bin_path('rake', 'rake'),
                                               *tasks, chdir: @project)
  end

  def tree
    Dir.glob('**/*', File::FNM_DOTMATCH, base: @project)
  end

  def test_default_full_and_targeted_tasks_do_not_create_reports
    before = tree
    [[], ['test'], ['test:shared']].each do |tasks|
      run_task(*tasks)
      assert @status.success?, @output + @errors
      assert_includes @output, '1 tests, 1 assertions'
      assert_equal before, tree
    end
  end

  def test_console_only_run_preserves_previous_reports
    report = '.tools/results/tests/TEST-previous.xml'
    write(report, '<previous/>')
    run_task('test')
    assert @status.success?, @output + @errors
    assert_equal '<previous/>', read(report)
  end

  def test_success_has_the_same_status_with_optional_reports
    assert_optional_report(true)
  end

  def test_failure_has_the_same_status_with_optional_reports
    write_probe(false)
    assert_optional_report(false)
  end

  def assert_optional_report(success)
    run_task('test:shared')
    assert_equal(success ? 0 : 1, @status.exitstatus, @output + @errors)
    refute_path_exists File.join(@project, 'reports')
    run_task('test:shared', reports: 'reports')
    assert_equal(success ? 0 : 1, @status.exitstatus, @output + @errors)
    assert_report(success)
  end

  def assert_report(success)
    suite = REXML::Document.new(read('reports/TEST-ReportingProbe.xml')).root.elements['testsuite']
    assert_equal '1', suite.attributes['tests']
    assert_equal success ? '0' : '1', suite.attributes['failures']
  end

  def test_requested_unwritable_report_is_an_error
    write('blocker', 'ordinary file')
    run_task('test', reports: 'blocker/reports')
    refute @status.success?, @output + @errors
    assert_equal 'ordinary file', read('blocker')
  end

  def test_documented_consumer_helper_also_requires_an_explicit_report_request
    guide = File.read(File.join(ROOT, '.tools/README.md'))
    section = guide.split("#### JUnit-rapportage instellen\n", 2).fetch(1)
    write('test_helper.rb', section[/^```ruby\n(.*?)^```/m, 1])
    write_probe(true, bootstrap: File.join(@project, 'test_helper'))
    before = tree
    assert_optional_report(true)
    assert_equal(before, tree.reject { |path| path == 'reports' || path.start_with?('reports/') })
  end
end
