# frozen_string_literal: true

require_relative 'support'

# Exercise native subprocess contracts at the public Rake boundary.
class ParallelReportingTest < Minitest::Test
  include ParallelTestSupport

  def test_native_default_and_parallel_reports_have_identical_cases_and_cleanup_once
    %w[Alpha Beta Gamma].each { |name| probe(name) }
    probe('Excluded', 'flunk', path: '.tools/sample/tests/fixtures/excluded_test.rb')
    [nil, '1', '2', '4'].each_with_index do |jobs, index|
      report = "reports #{index}"
      write("#{report}/TEST-old.xml", '<stale/>')
      write("#{report}/other.xml", '<preserved/>')
      run_tests(jobs, report: report, 'TESTOPTS' => '--seed=12345')
      assert_report_equivalence(report)
    end
  end

  def assert_report_equivalence(report)
    assert_success
    refute_path_exists File.join(@project, report, 'TEST-old.xml')
    assert_equal '<preserved/>', read("#{report}/other.xml")
    assert_equal identities('reports 0'), identities(report)
    assert_equal 3, identities(report).size
    assert_equal 1, @output.scan('[PASSED] Tool tests').size
    assert_equal 1, @output.scan('Tool: project-tools-tests ').size
  end

  def test_no_report_request_leaves_existing_reports_untouched
    %w[Alpha Beta].each { |name| probe(name) }
    write('reports/TEST-old.xml', '<preserved/>')
    run_tests
    assert_success
    assert_equal '<preserved/>', read('reports/TEST-old.xml')
    assert_equal ['reports/TEST-old.xml'], Dir.glob('**/*.xml', base: @project)
    refute_includes @output, 'JUnit written:'
  end

  def test_report_failure_is_incomplete_with_a_single_primary_result
    %w[Alpha Beta].each { |name| probe(name) }
    write('blocked', 'ordinary file')
    run_tests('2', report: 'blocked/reports')
    refute @status.success?
    assert_includes @output, 'Execution: incomplete'
    assert_equal 1, @output.scan('[ERROR] Tool tests').size
    refute_includes @output, 'JUnit written:'
    assert_equal 'ordinary file', read('blocked')
  end
end
