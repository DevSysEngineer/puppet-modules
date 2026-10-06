# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'metadata_cli_support'

# Root metadata is required independently of module and manifest selection.
class RootMetadataTest < Minitest::Test
  include MetadataCliSupport

  def test_root_is_required_without_modules_or_manifests_in_both_layouts
    [false, true].each do |repository|
      repository_layout if repository
      FileUtils.rm(File.join(@directory, 'metadata.json'))
      scan(prefix: nil)
      assert_metadata_error('metadata.json', 'metadata: missing metadata.json; expected a file in the project root')
      assert_equal 1, diagnostics(@output, 'project_metadata').size
    end
  end

  def test_invalid_root_json_is_not_fixed_or_repeated_for_each_manifest
    2.times { |index| write_file("manifests/file#{index}.pp", "$values = concat([1], [2])\n") }
    ['{"secret":"synthetic"', 'null', '[]'].each do |content|
      write_file('metadata.json', content)
      scan('--fix')
      assert_metadata_error('metadata.json', 'metadata:')
      assert_equal 1, diagnostics(@output, 'project_metadata').size
      refute_includes @output, 'synthetic'
      assert_equal content, File.read(File.join(@directory, 'metadata.json'))
    end
  end

  def test_each_root_field_is_required_and_reported_once
    project_metadata.each_key do |key|
      data = project_metadata.reject { |field, _value| field == key }
      write_file('metadata.json', JSON.generate(data))
      scan
      assert_metadata_error('metadata.json', "#{key}: expected")
      assert_equal 1, diagnostics(@output, 'project_metadata').size, key
    end
  end

  def test_repository_root_name_describes_the_project_and_not_a_module
    repository_layout
    write_file('metadata.json', JSON.generate(project_metadata(name: 'puppetmodules-docker')))
    scan
    assert_metadata_error('metadata.json', 'name: expected puppet-modules')
  end

  def test_root_version_follows_the_project_version_file_in_both_layouts
    [false, true].each do |repository|
      repository_layout if repository
      data = JSON.parse(File.read(File.join(@directory, 'metadata.json'))).merge('version' => '0.0.1')
      write_file('metadata.json', JSON.generate(data))
      scan
      assert_metadata_error('metadata.json', 'version: expected 7.4.0 from VERSION; found "0.0.1"')
    end
  end

  def test_clean_root_needs_no_module_prefix_and_ignores_metadata_beside_the_tooling
    write_file('global-modules/metadata.json', 'invalid shared metadata')
    scan(prefix: nil)
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_empty diagnostics(@output, 'project_metadata')
  end

  def test_module_validation_requires_only_the_module_schema_fields
    fields = %w[name version author summary license source dependencies]
    data = project_metadata(name: 'example-profile').slice(*fields)
    write_file('modules/profile/metadata.json', JSON.generate(data))
    scan
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_empty diagnostics(@output, 'project_metadata')
  end
end
