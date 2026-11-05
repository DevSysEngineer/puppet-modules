# frozen_string_literal: true

require_relative '../test_helper'

# Synthetic inputs and report assertions shared by the native cycle regressions.
module CatalogCycleTestSupport
  include CatalogTestSupport

  def prepare_cycle_module
    directory = module_inputs('cycle_probe', code: 'include cycle_probe')
    File.write(File.join(directory, 'manifests', 'init.pp'), <<~PUPPET)
      class cycle_probe {
        notify { 'cycle_probe_a': }
        notify { 'cycle_probe_b': }
        Notify['cycle_probe_a'] -> Notify['cycle_probe_b'] -> Notify['cycle_probe_a']
      }
    PUPPET
    directory
  end

  def assert_counts(expected)
    assert_equal(expected, %w[tests failures errors].map { |key| report_suite.attributes[key] })
  end

  def assert_cycle_console
    assert_match(%r{Dependency cycle.*Affected:\n    - cycle_probe/default \[debian\]}m, @console.string)
    assert_occurs_once('Found 1 dependency cycle')
    assert_includes @console.string, '(Notify[cycle_probe_a] => Notify[cycle_probe_b] => Notify[cycle_probe_a])'
    assert_includes @console.string, '2 selected | 2 processed | 2 checked'
  end

  def assert_later_success
    item = report_suite.get_elements('testcase').last
    assert item.elements['system-out']
    assert_nil item.elements['failure']
    assert_nil item.elements['error']
  end

  def containment_scenario
    scenario('containment', <<~PUPPET)
      class container { notify { 'inner': } }
      include container
      notify { 'outer': }
      Class['container'] -> Notify['outer'] -> Notify['inner']
    PUPPET
  end

  def assert_cycle_details
    item = report_suite.get_elements('testcase').first
    failure = item.elements['failure']
    details = failure.text
    assert_equal 'DependencyCycle', failure.attributes['type']
    assert_includes details, 'Compiled 6 resources.'
    assert_includes details, 'Definition coverage: 1/1'
    assert_includes details, 'Notify[cycle_probe_a] => Notify[cycle_probe_b] => Notify[cycle_probe_a]'
    assert_nil item.elements['system-out']
    assert_later_success
  end
end
