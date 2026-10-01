# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'metadata_cli_support'

# A consumer and its shared module project keep independent VERSION files and metadata.
class SharedVersionTest < Minitest::Test
  include MetadataCliSupport

  def setup
    super
    prepare_metadata_project(@directory, '3.1.0')
    metadata('modules/profile/metadata.json', version: '3.1.0')
    write_file('global-modules/VERSION', "2.0.0\n")
    write_file('global-modules/metadata.json', JSON.generate(project_metadata('2.0.0', name: 'puppet-modules')))
    write_file('global-modules/.tools/metadata/project-tools-metadata.gemspec', '')
    metadata('global-modules/docker/metadata.json', name: 'puppetmodules-docker', version: '2.0.0')
  end

  def test_each_project_uses_its_own_version_when_checked_from_its_root
    scan
    assert_equal 0, @status.exitstatus, @output + @errors
    capture_cli(directory: File.join(@directory, 'global-modules'), env: { 'PROJECT_METADATA_MODULES_PATH' => '.' })
    assert_equal 0, @status.exitstatus, @output + @errors
  end

  def test_missing_consumer_source_never_falls_back_to_shared_version
    FileUtils.rm(File.join(@directory, 'VERSION'))
    scan
    assert_metadata_error('VERSION', 'version: missing VERSION')
    assert_equal 1, diagnostics(@output, 'project_metadata').size
  end

  def test_version_change_fixes_own_files_without_changing_the_shared_project
    before = metadata_snapshot
    write_file('VERSION', "4.0.0\n")
    scan('--fix')
    assert_own_versions_fixed(before)
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_equal shared_metadata(before), shared_metadata(metadata_snapshot)
    assert_equal "4.0.0\n", File.read(File.join(@directory, 'VERSION'))
  end

  def assert_own_versions_fixed(before)
    %w[metadata.json modules/profile/metadata.json].each do |path|
      assert_includes @output, "#{path}:1:1: project_metadata: fixed: version: synchronized from VERSION"
      assert_equal before.fetch(path).sub('3.1.0', '4.0.0'), File.read(File.join(@directory, path))
    end
    assert_equal 2, diagnostics(@output, 'project_metadata').size
  end

  def shared_metadata(snapshot)
    snapshot.select { |path, _| path.start_with?('global-modules/') }
  end

  def metadata_snapshot
    %w[metadata.json modules/profile/metadata.json global-modules/VERSION
       global-modules/metadata.json global-modules/docker/metadata.json].to_h do |path|
      [path, File.binread(File.join(@directory, path))]
    end
  end
end
