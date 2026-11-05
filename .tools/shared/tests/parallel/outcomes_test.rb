# frozen_string_literal: true

require_relative 'support'

# Exercise native subprocess contracts at the public Rake boundary.
class ParallelOutcomesTest < Minitest::Test
  include ParallelTestSupport

  def test_failures_errors_and_skips_retain_all_diagnoses_and_other_workers_finish
    probe('Alpha', "flunk 'first failure'")
    probe('Beta', "raise 'second error'")
    probe('Gamma', "skip 'third skip'")
    probe('Delta', "File.write('finished', 'yes'); assert true")
    run_tests('4', report: 'reports')
    assert_all_outcomes
    assert_equal 'yes', read('finished')
    assert_equal 4, identities('reports').size
  end

  def assert_all_outcomes
    refute @status.success?
    assert_includes @output, '[ERROR] Tool tests'
    assert_includes @output, 'Execution: complete'
    assert_includes @output, '1 failures, 1 errors, 1 skips'
    %w[first second third].each do |message|
      assert_operator @output.index('[ERROR]'), :<, @output.index(message)
      assert_equal 1, @output.scan(message).size
    end
  end

  def test_skip_only_is_successful_and_assertion_failure_is_failed
    probe('Alpha', "skip 'policy skip'")
    probe('Beta')
    run_tests
    assert_success
    assert_includes @output, '1 skips'
    probe('Beta', "flunk 'contract failure'")
    run_tests
    refute @status.success?
    assert_includes @output, '[FAILED] Tool tests'
    assert_includes @output, 'Execution: complete'
  end

  def test_missing_corrupt_and_late_failed_results_cannot_pass
    probe('Beta')
    failed_result_bodies.each do |body|
      probe('Alpha', body)
      run_tests('2', report: 'reports')
      refute @status.success?
      assert_includes @output, '[ERROR] Tool tests'
      assert_includes @output, 'Execution: incomplete'
      assert identities('reports').key?(%w[Beta test_contract passed])
    end
  end

  def failed_result_bodies
    ['exit! 0', 'Minitest.after_run { exit! 7 }; assert true',
     "Minitest.after_run { File.write(ProjectTools::ParallelWorker::CONFIG.fetch('result'), '{') }; assert true"]
  end
end
