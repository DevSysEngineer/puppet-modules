# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'metadata_cli_support'

# Version and naming failures belong to the owning project, independently of Git.
class MetadataVersionTest < Minitest::Test
  include MetadataCliSupport

  def test_version_file_accepts_the_existing_numeric_version_format
    ['0.0.0', "7.4.0\n", "12.34.56\r\n"].each do |content|
      write_file('VERSION', content)
      assert_equal content.chomp, ProjectTools::Metadata::ProjectVersion.new(@directory).read
    end
  end

  def test_invalid_versions_fail_without_normalizing_or_using_metadata
    contents = ['', "\n", 'v7.4.0', '7.4', '07.4.0', '7.04.0', '7.4.00', '7.4.0-rc.1', '7.4.0+build',
                ' 7.4.0', '7.4.0 ', "7.4.0\n2.0.0", "7.4.0\n\n", "\xff".b]
    contents.each do |content|
      write_file('VERSION', content)
      error = assert_raises(ArgumentError) { ProjectTools::Metadata::ProjectVersion.new(@directory).read }
      assert_includes error.message, 'VERSION'
    end
  end

  def test_missing_version_file_fails_once_without_using_metadata
    metadata('modules/profile/metadata.json')
    metadata('modules/other/metadata.json', name: 'example-other')
    FileUtils.rm(File.join(@directory, 'VERSION'))
    scan
    assert_metadata_error('VERSION', 'version: missing VERSION; expected a file in the project root')
    assert_equal 1, diagnostics(@output, 'project_metadata').size
  end

  def test_empty_and_invalid_version_files_report_the_source_path_once
    ['', 'v7.4.0'].each do |content|
      write_file('VERSION', content)
      scan
      assert_metadata_error('VERSION', 'version: VERSION')
      assert_equal 1, diagnostics(@output, 'project_metadata').size
    end
  end

  def test_unreadable_version_file_is_a_source_error
    FileUtils.rm(File.join(@directory, 'VERSION'))
    FileUtils.mkdir_p(File.join(@directory, 'VERSION'))
    scan
    assert_metadata_error('VERSION', 'version: cannot read VERSION; expected a readable file')
  end

  def test_plain_project_without_git_repository_or_git_executable_passes
    metadata('modules/profile/metadata.json')
    bin = File.join(@directory, '.bin')
    FileUtils.mkdir_p(bin)
    File.symlink(RbConfig.ruby, File.join(bin, 'ruby'))
    environment = { 'PATH' => bin, 'PROJECT_METADATA_MODULES_PATH' => 'modules',
                    'PROJECT_METADATA_PREFIX' => 'example' }
    capture_cli(directory: @directory, env: environment)
    assert_equal 0, @status.exitstatus, @output + @errors
    refute_path_exists File.join(@directory, '.git')
  end

  def test_missing_consumer_naming_configuration_is_not_replaced_by_shared_prefix
    metadata('modules/profile/metadata.json', name: 'puppetmodules-profile')
    scan(prefix: nil)
    assert_metadata_error('configuration', 'name: set PROJECT_METADATA_PREFIX')
    refute_includes @output, 'name: expected puppetmodules'
  end

  def test_version_file_in_the_module_location_is_not_the_project_source
    write_file('modules/VERSION', "7.4.0\n")
    FileUtils.rm(File.join(@directory, 'VERSION'))
    scan
    assert_metadata_error('VERSION', 'version: missing VERSION')
  end
end
