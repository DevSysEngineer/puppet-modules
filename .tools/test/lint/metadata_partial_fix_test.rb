# frozen_string_literal: true

require_relative '../../lint/tests/test_helper'
require_relative 'metadata_cli_support'

# Missing information must not block independent repairs or hide incomplete metadata.
class MetadataPartialFixTest < Minitest::Test
  include MetadataCliSupport

  def test_missing_files_get_known_fields_and_persistent_errors_for_unknown_fields
    %w[modules site-modules].each do |location|
      FileUtils.mkdir_p(File.join(@directory, location, 'profile'))
      FileUtils.rm_f(File.join(@directory, 'metadata.json'))
      scan('.', modules_path: location)
      refute_path_exists File.join(@directory, location, 'profile/metadata.json')
      scan('--fix', '.', modules_path: location)
      assert_partial_metadata("#{location}/profile/metadata.json")
      assert_metadata_stable(["#{location}/profile/metadata.json", 'metadata.json'], modules_path: location)
    end
  end

  def assert_partial_metadata(path)
    assert_equal({ 'version' => '7.4.0' }, JSON.parse(contents('metadata.json')))
    assert_equal({ 'name' => 'example-profile', 'version' => '7.4.0' }, JSON.parse(contents(path)))
    assert_metadata_error(path, 'dependencies: expected an array')
    assert_metadata_error('metadata.json', 'name: expected a non-empty string')
  end

  def test_invalid_version_still_allows_independent_name_creation
    ['', 'not-a-version', nil].each do |version|
      path = 'modules/profile/metadata.json'
      FileUtils.mkdir_p(File.join(@directory, 'modules/profile'))
      FileUtils.rm_f(File.join(@directory, path))
      version ? write_file('VERSION', version) : FileUtils.rm_f(File.join(@directory, 'VERSION'))
      scan('--fix', '.')
      assert_metadata_error('VERSION', 'version:')
      assert_equal({ 'name' => 'example-profile' }, JSON.parse(contents(path)))
      assert_version_preserved(version)
    end
  end

  def assert_version_preserved(version)
    assert_equal version, contents('VERSION') if version
    assert_equal '7.4.0', JSON.parse(contents('metadata.json'))['version']
  end

  def test_missing_prefix_does_not_block_version_fix_or_creation
    metadata('modules/profile/metadata.json', version: '0.1.0')
    FileUtils.mkdir_p(File.join(@directory, 'modules/empty'))
    scan('--fix', '.', prefix: nil)
    assert_metadata_error('.puppet-lint.rc', 'name: set PROJECT_LINT_METADATA_PREFIX')
    assert_metadata_error('modules/empty/metadata.json', 'name: expected a non-empty string')
    assert_equal '7.4.0', JSON.parse(contents('modules/profile/metadata.json'))['version']
    assert_equal({ 'version' => '7.4.0' }, JSON.parse(contents('modules/empty/metadata.json')))
  end

  def test_no_known_fields_does_not_create_an_empty_object
    FileUtils.rm(File.join(@directory, 'VERSION'))
    FileUtils.rm(File.join(@directory, 'metadata.json'))
    scan('--fix', '.', prefix: nil)
    assert_metadata_error('metadata.json', 'metadata: cannot create metadata.json; provide')
    refute_path_exists File.join(@directory, 'metadata.json')
  end

  def test_missing_known_name_is_independent_of_an_invalid_version
    write_file('modules/profile/metadata.json', '{"custom":42}')
    write_file('VERSION', 'invalid')
    scan('--fix', '.')
    assert_metadata_error('VERSION', 'version:')
    assert_equal '{"custom":42, "name": "example-profile"}', contents('modules/profile/metadata.json')
    assert_metadata_stable(['modules/profile/metadata.json'])
  end

  def test_existing_name_is_preserved_while_version_is_repaired
    metadata('modules/profile/metadata.json', name: 'other-profile', version: '0.1.0')
    scan('--fix', '.')
    assert_metadata_error('modules/profile/metadata.json', 'name: expected example-profile')
    data = JSON.parse(contents('modules/profile/metadata.json'))
    assert_equal 'other-profile', data['name']
    assert_equal '7.4.0', data['version']
  end
end
