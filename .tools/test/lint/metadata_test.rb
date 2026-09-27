# frozen_string_literal: true

require_relative '../../lint/tests/test_helper'
require_relative 'metadata_cli_support'

# Exercise project-level metadata through the same CLI used locally and in CI.
class MetadataTest < Minitest::Test
  include MetadataCliSupport

  def test_repository_modules_without_manifests_require_metadata
    repository_layout
    FileUtils.mkdir_p(File.join(@directory, 'new_module/templates'))
    scan('.')
    assert_metadata_error('new_module/metadata.json', 'metadata: missing metadata.json')
    assert_equal 1, diagnostics(@output, 'project_metadata').size
    metadata('new_module/metadata.json', name: 'puppetmodules-new_module')
    scan('.')
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_empty @output
  end

  def test_consumer_uses_its_own_version_and_prefix_without_scanning_shared_modules
    metadata('modules/profile/metadata.json')
    write_file('global-modules/.tools/lint/lint-project.gemspec', '')
    metadata('global-modules/docker/metadata.json', name: 'puppetmodules-docker', version: '2.0.0')
    scan('modules')
    assert_equal 0, @status.exitstatus, @output + @errors
    metadata('modules/profile/metadata.json', version: '2.0.0')
    shared = File.read(File.join(@directory, 'global-modules/docker/metadata.json'))
    scan('--fix', 'modules')
    assert_metadata_error('modules/profile/metadata.json', 'version: expected 7.4.0')
    assert_equal shared, File.read(File.join(@directory, 'global-modules/docker/metadata.json'))
  end

  def test_consumer_missing_metadata_is_reported_once_even_with_multiple_manifests
    2.times { |index| write_file("modules/profile/manifests/file#{index}.pp", "$values = concat([1], [2])\n") }
    FileUtils.mkdir_p(File.join(@directory, 'modules/empty'))
    scan('modules')
    assert_metadata_error('modules/profile/metadata.json', 'metadata: missing metadata.json')
    assert_equal 2, diagnostics(@output, 'project_metadata').size
    assert_includes @output, 'modules/empty/metadata.json'
    refute_includes @output, 'manifests/metadata.json'
  end

  def test_invalid_json_and_non_objects_are_single_diagnostics_without_source_excerpts
    ['{"secret":"synthetic"', 'null', '[]'].each do |content|
      write_file('modules/profile/metadata.json', content)
      scan('--fix', '--with-context', 'modules')
      assert_metadata_error('modules/profile/metadata.json', 'metadata:')
      assert_equal 1, diagnostics(@output, 'project_metadata').size
      refute_includes @output, 'synthetic'
      assert_equal content, File.read(File.join(@directory, 'modules/profile/metadata.json'))
    end
  end

  def test_names_and_versions_are_checked_for_both_layouts
    { 'modules/profile' => 'example-profile', 'docker' => 'puppetmodules-docker' }.each do |directory, expected|
      repository_layout if directory == 'docker'
      metadata("#{directory}/metadata.json", name: 'wrong-module', version: '0.0.1')
      scan(directory)
      assert_metadata_error("#{directory}/metadata.json", "name: expected #{expected}")
      assert_includes @output, 'version: expected 7.4.0'
      FileUtils.remove_entry(File.join(@directory, 'modules')) if directory.start_with?('modules/')
    end
  end

  def test_missing_properties_are_reported
    write_file('modules/profile/metadata.json', '{}')
    scan('.')
    assert_metadata_error('modules/profile/metadata.json', 'name: expected example-profile')
    assert_equal 2, diagnostics(@output, 'project_metadata').size
  end

  def test_technical_vendored_and_explicitly_excluded_directories_are_not_modules
    repository_layout
    %w[.github .tools .cache examples vendor concat debconf reboot stdlib timezone ignored].each do |path|
      FileUtils.mkdir_p(File.join(@directory, path))
    end
    metadata('docker/metadata.json', name: 'puppetmodules-docker')
    scan('--ignore-paths=ignored/*', '.')
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_empty @output
  end

  def test_native_check_selection_and_inventory_do_not_run_metadata
    FileUtils.mkdir_p(File.join(@directory, 'modules/empty'))
    scan('--only-checks=project_arrays', 'modules')
    assert_equal 0, @status.exitstatus, @output + @errors
    scan('--list-checks')
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_equal(1, @output.lines.count { |line| line.strip == 'project_metadata' })
  end
end
