# frozen_string_literal: true

require_relative '../test_helper'

# Discovery failures must remain visible alongside independent compilation outcomes.
class CatalogDiscoveryErrorsTest < Minitest::Test
  include CatalogTestSupport

  def test_no_modules_with_tests_cannot_produce_a_successful_check
    FileUtils.mkdir_p(File.join(@root, 'untested', 'manifests'))
    assert_equal 1, run_catalogs(nil, report: File.join(@root, 'reports', 'catalog.xml'))
    assert_equal '1', report_suite.attributes['errors']
    assert_includes @console.string, 'No catalog scenarios selected.'
    assert_includes @console.string, 'Modules without tests: 1 skipped'
  end

  def test_incomplete_modules_and_compilation_failures_do_not_hide_later_success
    prepare_mixed_modules
    assert_equal 1, run_catalogs(nil, report: File.join(@root, 'reports', 'catalog.xml'))
    assert_discovery_results
    assert_mixed_console
  end

  def assert_mixed_console
    assert_includes @console.string, 'Duplicate declaration'
    assert_includes @console.string, 'no_facts/discovery'
    assert_includes @console.string, 'no_manifests/discovery'
    assert_includes @console.string, '2 selected | 2 checked'
    assert_primary_status('ERROR')
    assert_includes @console.string, '1 failures | 2 errors'
    assert_occurs_once('Duplicate declaration')
    assert_occurs_once('no_facts/discovery')
    assert_occurs_once('no_manifests/discovery')
  end

  def prepare_mixed_modules
    module_inputs('broken', code: "notify { 'duplicate': } notify { 'duplicate': }")
    no_facts = module_inputs('no_facts')
    FileUtils.remove_entry(File.join(no_facts, 'tests', 'facts'))
    no_manifests = module_inputs('no_manifests')
    FileUtils.remove_entry(File.join(no_manifests, 'tests', 'manifests'))
    module_inputs('valid')
  end

  def assert_discovery_results
    assert_equal(%w[4 1 2], %w[tests failures errors].map { |key| report_suite.attributes[key] })
    last = report_suite.get_elements('testcase').last
    assert_equal 'valid/default [debian]', last.attributes['name']
    assert_nil last.elements['error']
  end

  def test_empty_test_directory_is_an_error_but_modules_without_tests_are_skipped
    FileUtils.mkdir_p(File.join(@root, 'empty', 'tests'))
    FileUtils.mkdir_p(File.join(@root, 'untested', 'manifests'))
    assert_equal 1, run_catalogs(nil, report: File.join(@root, 'reports', 'catalog.xml'))
    assert_equal '1', report_suite.attributes['errors']
    assert_includes @console.string, 'Modules without tests: 1 skipped'
    assert_includes @console.string, 'empty/discovery'
  end

  def test_invalid_modulepaths_report_errors_instead_of_using_the_current_directory
    ['', 'relative', File.join(@root, 'absent'), "#{@root}#{File::PATH_SEPARATOR}"].each do |path|
      runner = ProjectTools::Catalog.new(modulepath: path, console: @console)
      assert_equal 1, runner.run(report: File.join(@root, 'reports', 'catalog.xml'))
      assert_equal(%w[1 0 1], %w[tests failures errors].map { |key| report_suite.attributes[key] })
    end
  end

  def test_broken_input_symlinks_do_not_omit_tests_or_block_other_modules
    directory = module_inputs('broken')
    File.symlink('missing.pp', File.join(directory, 'tests', 'manifests', 'missing.pp'))
    module_inputs('valid')
    discovery = ProjectTools::Catalog::Discovery.new([@root])
    assert_equal(['valid/default [debian]'], discovery.scenarios.map { |item| item[:name] })
    assert_equal 1, discovery.errors.size
    assert_includes discovery.errors.first[:message], 'must not be symlinks'
  end

  def test_missing_module_directory_keeps_results_from_other_modulepaths
    module_inputs('valid')
    discovery = ProjectTools::Catalog::Discovery.new([File.join(@root, 'missing'), @root])
    assert_equal 1, discovery.errors.size
    assert_equal(['valid/default [debian]'], discovery.scenarios.map { |item| item[:name] })
  end
end
