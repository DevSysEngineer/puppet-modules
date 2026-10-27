# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'
require 'rexml/document'
require 'yaml'

require_relative 'catalog_support'

# Exercise the actual entry points from an independent bundle and a relocated checkout.
class CatalogIntegrationTest < Minitest::Test
  include CatalogConsumerSupport

  def test_default_checkout_selection_is_independent_of_current_directory_for_both_entry_points
    sample_module('elsewhere', 'decoy', body: "fail('wrong directory')")
    %i[cli rake].each do |entry|
      invoke(entry, report: true)
      assert @status.success?, @output + @errors
      assert_counts(%w[1 0 0])
      assert_equal 'sample/default [synthetic]', suite.elements['testcase'].attributes['name']
      assert_report_preserved(entry)
    end
  end

  def assert_report_preserved(entry)
    write('elsewhere/catalog.xml', '<previous/>')
    invoke(entry)
    assert @status.success?, @output + @errors
    assert_equal '<previous/>', read('elsewhere/catalog.xml')
  end

  def assert_counts(expected)
    assert_equal(expected, %w[tests failures errors].map { |key| suite.attributes[key] })
  end

  def test_consumer_modulepath_discovers_new_tests_and_uses_the_same_order_for_compilation
    prepare_modulepath
    %i[cli rake].each do |entry|
      invoke(entry, report: true)
      assert @status.success?, @output + @errors
      assert_counts(%w[2 0 0])
      assert_equal(['profile/combined/default [synthetic]', 'sample/default [synthetic]'],
                   suite.get_elements('testcase').map { |item| item.attributes['name'] })
    end
  end

  def test_failure_and_error_statuses_reach_ci_without_hiding_successful_modules
    sample_module('global-modules', 'failure', body: "notify { 'same': } notify { 'same': }")
    write('global-modules/invalid/tests/facts/invalid.json', '[]')
    write('global-modules/invalid/tests/manifests/default.pp', "notify { 'valid syntax': }")
    %i[cli rake].each do |entry|
      [false, true].each { |report| assert_mixed_results(entry, report: report) }
      assert_counts(%w[3 1 1])
    end
  end

  def assert_mixed_results(entry, report:)
    invoke(entry, report: report)
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @output, 'Duplicate declaration'
    assert_includes @output, 'Expected a JSON object of facts'
    assert_includes @output, 'sample/default [synthetic]'
  end

  def test_hiera_fixtures_work_from_consumer_modulepath_for_cli_and_rake_with_optional_reports
    prepare_hiera_consumer
    %i[cli rake].each { |entry| assert_hiera_success(entry) }
    write('modules/sample/tests/hiera/data/common.yaml', '{}')
    %i[cli rake].each { |entry| assert_hiera_error(entry, %w[2 1 0]) }
    write('modules/sample/tests/hiera/hiera.yaml', '')
    %i[cli rake].each { |entry| assert_hiera_error(entry, %w[2 0 1]) }
  end

  def prepare_hiera_consumer
    prepare_modulepath
    write('modules/sample/manifests/init.pp', <<~PUPPET)
      class sample(Sensitive[String] $password) {
        if $password.unwrap != '#{SYNTHETIC_VALUE}' { fail('wrong consumer fixture') }
      }
    PUPPET
    %w[profile sample].each { |name| consumer_hiera(name) }
  end

  def assert_hiera_success(entry)
    invoke(entry, report: true)
    assert @status.success?, @output + @errors
    assert_counts(%w[2 0 0])
    assert_equal(['profile/combined/default [synthetic]', 'sample/default [synthetic]'],
                 suite.get_elements('testcase').map { |item| item.attributes['name'] })
    assert_report_preserved(entry)
    refute_includes @output, SYNTHETIC_VALUE
  end

  def assert_hiera_error(entry, counts)
    invoke(entry, report: true)
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_counts(counts)
    assert_includes @output, 'sample/'
    write('elsewhere/catalog.xml', '<previous/>')
    invoke(entry)
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_equal '<previous/>', read('elsewhere/catalog.xml')
  end
end
