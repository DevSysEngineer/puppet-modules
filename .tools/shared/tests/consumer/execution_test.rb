# frozen_string_literal: true

require_relative 'support'

# Native and parallel installed routes must select the same consumer-owned cases.
class SharedConsumerExecutionTest < Minitest::Test
  include SharedConsumerSupport

  def test_installed_gem_runs_without_puppet_and_preserves_case_identity
    selected = [1, 2, 4].map do |jobs|
      run_suite(jobs, 'MINITEST_REPORTERS_REPORTS_DIR' => 'reports')
      assert @status.success?, @output + @errors
      assert_includes @output + @errors, 'Puppet runtime: not required'
      assert_equal 4, cases.size
      cases
    end
    assert_equal [selected.first], selected.uniq
    refute_path_exists File.join(@project, 'VERSION')
  end

  def test_native_selection_and_failure_status_work_without_report_mutation
    write('reports/TEST-old.xml', 'previous')
    write_probe(2, "flunk 'consumer failure'")
    run_suite(2)
    refute @status.success?
    assert_includes @output + @errors, 'consumer failure'
    assert_equal 'previous', read('reports/TEST-old.xml')
    run_suite(4, 'TEST' => 'tests/probe0_test.rb', 'TESTOPTS' => '--name=/contract/ --seed=12345')
    assert @status.success?, @output + @errors
    assert_includes @output, '1 tests, 3 assertions'
    assert_equal 'previous', read('reports/TEST-old.xml')
  end
end
