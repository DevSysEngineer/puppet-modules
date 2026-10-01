# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'metadata_cli_support'

# Exercise writes, partial repairs and project ownership through the public CLI.
class MetadataAutofixTest < Minitest::Test
  include MetadataCliSupport

  def formatted_metadata
    data = project_metadata('0.1.0', name: 'example-profile')
    data['custom'] = { 'version' => 'unchanged', 'text' => 'Quotes " and unicode é' }
    JSON.pretty_generate(data).gsub("\n", "\r\n")
  end

  def test_version_replacement_preserves_unrelated_json_and_file_mode
    path = 'modules/profile/metadata.json'
    original = formatted_metadata
    file = write_file(path, original)
    File.chmod(0o640, file)
    scan
    assert_metadata_error(path, 'version: expected 7.4.0')
    assert_equal original, contents(path)
    assert_version_repaired(path, original)
    assert_equal 0o640, File.stat(file).mode & 0o777
  end

  def assert_version_repaired(path, original)
    scan('--fix')
    assert_equal 0, @status.exitstatus, @output + @errors
    expected = original.sub('"version": "0.1.0"', '"version": "7.4.0"')
    assert_equal expected, contents(path)
    scan
    assert_empty @output
    assert_metadata_stable([path])
  end

  def test_missing_version_is_inserted_without_reserializing_existing_values
    path = 'modules/profile/metadata.json'
    original = '{"name":"example-profile", "custom":{"version":3e2}}'
    write_file(path, original)
    scan('--fix')
    assert_equal '{"name":"example-profile", "custom":{"version":3e2}, "version": "7.4.0"}', contents(path)
    assert_metadata_error(path, 'author: expected a non-empty string')
    refute_includes @output, 'error: version:'
    assert_metadata_stable([path])
  end

  def test_all_json_value_types_and_escaped_version_key_can_be_repaired
    ['null', '42', '[]', '{"nested":[1,2]}', 'false', '"wrong"'].each do |value|
      source = "{\"ver\\u0073ion\" : #{value},\"extra\": {\"version\": 1}}"
      write_file('metadata.json', source)
      scan('--fix')
      assert_equal source.sub(" : #{value},", ' : "7.4.0",'), contents('metadata.json')
      refute_includes @output, 'error: version:'
    end
  end

  def test_duplicate_version_keys_remain_unchanged
    source = '{"version":"0.1.0","version":"0.2.0"}'
    write_file('modules/profile/metadata.json', source)
    metadata('modules/other/metadata.json', name: 'example-other', version: '0.1.0')
    scan('--fix')
    assert_metadata_error('modules/profile/metadata.json', 'version: duplicate top-level keys prevent safe autofix')
    assert_equal source, contents('modules/profile/metadata.json')
    assert_equal '7.4.0', JSON.parse(contents('modules/other/metadata.json'))['version']
  end

  def test_symlinks_remain_unchanged
    source = '{"version":"0.1.0"}'
    FileUtils.mkdir_p(File.join(@directory, 'modules/profile'))
    write_file('.external.json', source)
    File.symlink('../../.external.json', File.join(@directory, 'modules/profile/metadata.json'))
    scan('--fix')
    assert_metadata_error('modules/profile/metadata.json', 'metadata: autofix skips symbolic links')
    assert_equal source, contents('.external.json')
  end

  def test_nested_project_and_excluded_modules_are_not_rewritten
    metadata('modules/profile/metadata.json', version: '0.1.0')
    metadata('modules/imported/metadata.json', name: 'other-imported', version: '2.0.0')
    write_file('modules/imported/VERSION', "2.0.0\n")
    FileUtils.mkdir_p(File.join(@directory, 'modules/ignored'))
    before = contents('modules/imported/metadata.json')
    scan('--fix', '--ignore-paths=modules/ignored/*')
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_equal before, contents('modules/imported/metadata.json')
    refute_path_exists File.join(@directory, 'modules/ignored/metadata.json')
  end

  def test_module_location_inside_an_imported_project_is_rejected
    metadata('modules/imported/metadata.json', name: 'other-imported', version: '2.0.0')
    write_file('modules/imported/VERSION', "2.0.0\n")
    before = contents('modules/imported/metadata.json')
    scan('--fix', modules_path: 'modules/imported')
    assert_metadata_error('configuration', 'modules_path: selects another project')
    assert_equal before, contents('modules/imported/metadata.json')
  end

  def test_invalid_options_do_not_write
    metadata('modules/profile/metadata.json', version: '0.1.0')
    before = contents('modules/profile/metadata.json')
    scan('--fix', '--invalid-autofix-option')
    assert_equal 2, @status.exitstatus
    assert_equal before, contents('modules/profile/metadata.json')
    scan('--fix', 'unexpected', 'arguments')
    assert_equal 2, @status.exitstatus
    assert_equal before, contents('modules/profile/metadata.json')
  end
end
