# frozen_string_literal: true

require_relative 'test_helper'

# Real native graphs prove that compilation alone is insufficient, without applying resources.
class CatalogDependencyCycleValidationTest < Minitest::Test
  include CatalogCycleTestSupport

  def test_compiled_cycle_fails_with_full_coverage_and_later_scenario_still_passes
    directory = prepare_cycle_module
    target = File.join(@root, 'must not be applied')
    File.write(File.join(directory, 'tests/manifests/later.pp'), "file { '#{target}': ensure => file }")
    assert_equal 1, run_catalogs(nil, report: report_path)
    assert_primary_status('FAILED')
    assert_counts(%w[2 1 0])
    assert_cycle_console
    assert_cycle_details
    refute_path_exists target
  end

  def test_cycle_fails_without_report_and_preserves_existing_report
    prepare_cycle_module
    report = stale_report
    assert_equal 1, run_catalogs(nil)
    assert_primary_status('FAILED')
    assert_equal '<previous/>', File.read(report)
    refute_includes @console.string, 'JUnit written:'
  end

  def test_notification_and_self_cycles_use_native_paths_instead_of_sorted_components
    inputs = [scenario('notification', <<~PUPPET), scenario('self', "notify { 'self': before => Notify['self'] }")]
      notify { 'a': }
      notify { 'z': }
      notify { 'm': }
      Notify['a'] ~> Notify['z'] -> Notify['m'] -> Notify['a']
    PUPPET
    assert_equal 1, run_catalogs(inputs, report: report_path)
    assert_counts(%w[2 2 0])
    assert_includes @console.string, '(Notify[a] => Notify[z] => Notify[m] => Notify[a])'
    assert_includes @console.string, '(Notify[self] => Notify[self])'
  end

  def test_containment_closes_a_cycle_after_compilation
    input = containment_scenario
    assert_equal 1, run_catalogs([input], report: report_path)
    assert_counts(%w[1 1 0])
    details = report_suite.elements['testcase/failure'].text
    ['DependencyCycle', 'Notify[inner]', 'Notify[outer]', 'Class[Container]'].each do |text|
      assert_includes File.read(report_path), text
    end
    assert_includes details, 'Compiled '
  end

  def test_parent_file_autorequire_is_needed_to_close_the_cycle
    inputs = [scenario('autorequire', automatic_relationship('parent/child')),
              scenario('independent', automatic_relationship('independent'))]
    assert_equal 1, run_catalogs(inputs, report: report_path)
    assert_counts(%w[2 1 0])
    details = report_suite.elements['testcase/failure'].text
    assert_includes details, 'File[/synthetic/parent] => File[/synthetic/parent/child]'
    assert_includes details, 'File[/synthetic/parent/child] => Notify[bridge] => File[/synthetic/parent]'
    assert_later_success
    assert_primary_status('FAILED')
  end

  def automatic_relationship(child)
    <<~PUPPET
      file { '/synthetic/parent': ensure => directory }
      file { '/synthetic/#{child}': ensure => file }
      notify { 'bridge': }
      File['/synthetic/#{child}'] -> Notify['bridge'] -> File['/synthetic/parent']
    PUPPET
  end
end
