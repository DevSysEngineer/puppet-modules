# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'metadata_cli_support'

# Projects explicitly select module metadata independently of their root metadata.
class ModulesPathTest < Minitest::Test
  include MetadataCliSupport

  def test_explicit_directory_names_select_only_their_direct_modules
    %w[modules site-modules].each do |location|
      metadata("#{location}/profile/metadata.json", name: 'wrong-profile', version: '0.0.1')
      write_file('unselected/empty/files/example.txt', '')
      scan('.', modules_path: location)
      assert_metadata_error("#{location}/profile/metadata.json", 'name: expected example-profile')
      assert_includes @output, 'version: expected 7.4.0 from VERSION; found "0.0.1"'
      metadata("#{location}/profile/metadata.json")
      scan('.', modules_path: location)
      assert_equal 0, @status.exitstatus, @output + @errors
    end
  end

  def test_repository_can_explicitly_select_modules_in_a_different_directory
    repository_layout
    metadata('site-modules/docker/metadata.json', name: 'puppetmodules-docker')
    write_file('site-modules/concat/files/example.txt', '')
    scan('.', modules_path: 'site-modules')
    assert_equal 0, @status.exitstatus, @output + @errors
  end

  def test_relative_parent_paths_keep_metadata_paths_relative_to_the_project_root
    Dir.mktmpdir('lint-modules-', File.dirname(@directory)) do |modules|
      location = Pathname.new(modules).relative_path_from(Pathname.new(@directory)).to_s
      metadata("#{location}/profile/metadata.json", version: '0.0.1')
      scan('.', modules_path: location)
      assert_metadata_error("#{location}/profile/metadata.json", 'version: expected 7.4.0')
    end
  end

  def test_consumer_dot_keeps_own_naming_and_directory_exclusions
    metadata('profile/metadata.json')
    write_file('dependency/files/example.txt', '')
    write_file('.hidden/files/example.txt', '')
    File.symlink('profile', File.join(@directory, 'linked_profile'))
    scan('--ignore-paths=modules/*,dependency/*', '.', modules_path: '.')
    assert_equal 0, @status.exitstatus, @output + @errors
    metadata('profile/metadata.json', name: 'puppetmodules-profile')
    scan('--ignore-paths=modules/*,dependency/*', '.', modules_path: '.')
    assert_metadata_error('profile/metadata.json', 'name: expected example-profile')
  end

  def test_missing_or_empty_setting_never_falls_back_to_an_existing_module_location
    metadata('modules/profile/metadata.json', version: '0.0.1')
    metadata('profile/metadata.json', version: '0.0.1')
    [nil, ''].each do |location|
      scan('.', modules_path: location)
      assert_metadata_error('.puppet-lint.rc', 'modules_path: set PROJECT_LINT_MODULES_PATH')
      assert_equal 1, diagnostics(@output, 'project_metadata').size
    end
  end

  def test_nonexistent_directory_file_and_absolute_path_are_configuration_errors
    write_file('plain-file', '')
    ['absent', 'plain-file', @directory].each do |location|
      scan('.', modules_path: location)
      assert_metadata_error('.puppet-lint.rc', 'modules_path:')
      assert_includes @output, 'PROJECT_LINT_MODULES_PATH'
      assert_equal 1, diagnostics(@output, 'project_metadata').size
    end
  end

  def test_root_metadata_is_checked_even_when_module_location_is_invalid
    FileUtils.rm(File.join(@directory, 'metadata.json'))
    [nil, '', 'absent'].each do |location|
      scan('.', modules_path: location)
      assert_metadata_error('.puppet-lint.rc', 'modules_path:')
      assert_metadata_error('metadata.json', 'metadata: missing metadata.json')
      assert_equal 2, diagnostics(@output, 'project_metadata').size
    end
  end

  def test_root_metadata_is_not_read_from_the_configured_module_directory
    write_file('site-modules/metadata.json', JSON.generate(project_metadata))
    FileUtils.rm(File.join(@directory, 'metadata.json'))
    scan('.', modules_path: 'site-modules')
    assert_metadata_error('metadata.json', 'metadata: missing metadata.json')
    assert_equal 1, diagnostics(@output, 'project_metadata').size
  end
end
