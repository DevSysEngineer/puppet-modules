# frozen_string_literal: true

require_relative 'test_helper'

# Match native first-name selection, including shadowing and metadata-free directories.
class DependencySelectionTest < Minitest::Test
  include DependencyTestSupport

  def test_matching_range_and_native_missing_range
    write_module('consumer', dependencies: [{ 'name' => 'example-library' }])
    write_module('library', version: '2.1.0')
    write_root([dependency])
    scan(0)
    assert_equal '1', @suite.attributes['tests']
    assert_includes @output, 'Module metadata assessed: 2.'
    assert_empty @errors
  end

  def test_exact_lower_and_upper_bound_conflicts
    ['= 2.0.0', '>= 3.0.0', '< 2.0.0'].each do |range|
      write_module('consumer', dependencies: [dependency('example-library', range)])
      write_module('library', version: '2.1.0')
      scan(1)
      assert_equal(['version_mismatch'], junit_failures.map { |node| node.attributes['type'] })
      assert_includes @output, "requires #{range}; selected 2.1.0"
    end
  end

  def test_external_and_multiple_requesters_remain_separate
    write_module('consumer', dependencies: [dependency('vendor-external', '>= 1.0.0')])
    write_module('external', owner: 'vendor', dependencies: [dependency])
    write_module('second', dependencies: [dependency])
    write_module('library', version: '4.0.0')
    scan(1)
    assert_equal 2, junit_failures.length
    assert_includes @output, 'vendor/external'
    assert_includes @output, 'example/second'
  end

  def test_native_cli_agrees_on_conflict_reasons_ranges_and_selected_versions
    write_module('consumer', dependencies: [dependency, dependency('example-missing')])
    write_module('library', version: '4.0.0')
    scan(1)
    native = native_list.fetch('unmet_dependencies')
    assert_equal %w[missing version_mismatch], junit_failures.map { |node| node.attributes['type'] }.sort
    assert_native_details(native)
  end

  def assert_native_details(native)
    %w[missing version_mismatch].each { |reason| refute_empty native.fetch(reason) }
    text = JSON.generate(native)
    assert_includes text, 'example/consumer'
    assert_includes text, '4.0.0'
    assert_includes text, '>= 2.0.0 < 3.0.0'
  end

  def test_modulepath_order_determines_selection
    write_module('consumer', dependencies: [dependency])
    write_module('library', version: '1.0.0')
    write_module('library', version: '2.0.0', base: @second)
    scan(1)
    @env['PROJECT_TOOLS_MODULEPATH'] = [@second, @first].join(File::PATH_SEPARATOR)
    scan(0)
  end

  def test_empty_first_directory_does_not_fall_back
    write_module('consumer', dependencies: [dependency])
    write_module('library', version: '2.0.0', base: @second)
    FileUtils.mkdir_p(File.join(@first, 'library'))
    scan(1)
    assert_equal 'missing', junit_failures.first.attributes['type']
    assert_includes @output, 'Directories not assessed for metadata: 1.'
  end

  def test_wrong_forge_owner_does_not_fall_back
    write_module('consumer', dependencies: [dependency])
    write_module('library', version: '2.0.0', base: @second)
    write_module('library', owner: 'another', version: '2.0.0')
    scan(1)
    assert_equal 'missing', junit_failures.first.attributes['type']
  end

  def test_native_symlink_and_unassessed_directories
    directory = write_module('library', version: '2.0.0', base: @second)
    File.symlink(directory, File.join(@first, 'library'))
    %w[examples vendor].each { |name| FileUtils.mkdir_p(File.join(@first, name)) }
    write_root([dependency])
    scan(0)
    assert_includes @output, 'Module metadata assessed: 1.'
    assert_includes @output, 'Directories not assessed for metadata: 2.'
  end

  def test_invalid_range_is_a_native_finding
    write_module('consumer', dependencies: [dependency('example-library', 'not a range')])
    write_module('library')
    scan(1)
    assert_equal 'non_semantic_version', junit_failures.first.attributes['type']
    refute_empty native_list.fetch('unmet_dependencies').fetch('non_semantic_version')
  end
end
