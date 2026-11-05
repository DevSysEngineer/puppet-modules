# frozen_string_literal: true

require_relative 'result_support'

# Reject malformed or inconsistent worker records before trusting their totals.
class ParallelResultsTest < Minitest::Test
  include ParallelResultSupport

  def invalid_fields
    [[%w[schema_version], 2], [%w[worker_id], 'another'], [%w[selected_files], []],
     [%w[execution], 'success'], [%w[expected_tests], 2], [%w[counts assertions], -1],
     [%w[counts tests], 2], [['cases', 0, 'outcome'], 'invalid'], [%w[counts failures], 1],
     [%w[duration_seconds], '1'], [%w[seed], nil], [%w[junit_files], ['../TEST-outside.xml']]]
  end

  def test_rejects_invalid_protocol_fields_and_counts
    invalid_fields.each do |path, value|
      results = ProjectTools::ParallelResults.new
      accept(results, *invalid_result(path, value))
      assert_equal 'ERROR', results.status
      assert_equal 'incomplete', results.execution
    end
  end

  def invalid_result(path, value)
    config, data = result
    target = path.size == 1 ? data : data.dig(*path[0...-1])
    target[path.last] = value
    [config, data]
  end

  def test_missing_diagnosis_is_an_error
    results = ProjectTools::ParallelResults.new
    config, data = result
    data['cases'][0]['outcome'] = 'failure'
    data['counts']['failures'] = 1
    accept(results, config, data)
    assert_equal 'ERROR', results.status
    assert_match(/Missing native diagnosis/, results.errors.join)
  end

  def test_duplicate_identities_and_unexpected_process_exit_are_errors
    results = ProjectTools::ParallelResults.new
    accept(results, *result)
    accept(results, *result('worker-01'))
    assert_match(/Duplicate testcase/, results.errors.join)
    assert_equal 'ERROR', results.status
    results = ProjectTools::ParallelResults.new
    accept(results, *result, code: 7)
    assert_match(/unexpected process status/, results.errors.join)
  end
end
