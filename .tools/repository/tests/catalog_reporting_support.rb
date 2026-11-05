# frozen_string_literal: true

# Console and JUnit assertions for the actual consumer entry points.
module CatalogConsumerReportingSupport
  def assert_consumer_failure
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_log_status('FAILED')
    assert_counts(%w[2 1 0])
    assert_includes @output, '[FINDING] Puppet catalogs | failure/default [synthetic] | Compilation failure'
    assert_equal 1, @output.scan('synthetic consumer failure').size
    assert_includes suite.elements['testcase/failure'].text, 'synthetic consumer failure'
  end

  def assert_mixed_results(entry, report:)
    invoke(entry, report: report)
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @output, 'Duplicate declaration'
    assert_includes @output, 'Expected a JSON object of facts'
    assert_log_status('ERROR')
    assert_includes @output, '4 selected | 3 checked'
    assert_includes @output, '2 failures | 1 errors'
    assert_cycle_console
  end

  def assert_cycle_console
    assert_includes @output, 'cycle_probe/default [synthetic] | Dependency cycle'
    ['Found 1 dependency cycle', 'Duplicate declaration', 'Expected a JSON object of facts'].each do |message|
      assert_equal 1, @output.scan(message).size
    end
  end

  def assert_cycle_report
    item = suite.get_elements('testcase').find { |test| test.attributes['name'] == 'cycle_probe/default [synthetic]' }
    assert_cycle_case(item)
    assert suite.get_elements('testcase').last.elements['system-out']
  end

  def assert_cycle_case(item)
    assert_equal 'DependencyCycle', item.elements['failure'].attributes['type']
    assert_cycle_details(item.elements['failure'].text)
    assert_nil item.elements['system-out']
  end

  def assert_cycle_details(details)
    assert_includes details, 'Definition coverage: 1/1'
    assert_includes details, 'Notify[cycle_probe_a] => Notify[cycle_probe_b] => Notify[cycle_probe_a]'
  end

  def assert_default_success_log
    assert_log_status('PASSED')
    assert_includes suite.elements['testcase/system-out'].text, 'Compiled definitions: class sample'
  end

  def assert_counts(expected)
    assert_equal(expected, %w[tests failures errors].map { |key| suite.attributes[key] })
    assert_includes suite.elements['testcase/system-out'].text, 'Definition coverage' if expected == %w[1 0 0]
  end

  def assert_deprecation_failure
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_log_status('FAILED')
    assert_counts(%w[4 1 0])
    assert_equal 'Deprecation', suite.elements['testcase/failure'].attributes['type']
    assert_includes @output, 'legacy/default [synthetic] | Deprecated Puppet usage'
    assert_equal 1, @output.scan('synthetic consumer deprecation').size
    assert_includes @output, '4 selected | 4 checked'
  end
end
