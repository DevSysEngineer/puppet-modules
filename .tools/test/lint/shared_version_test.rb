# frozen_string_literal: true

require_relative '../../lint/tests/test_helper'
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
    write_file('global-modules/.tools/lint/lint-project.gemspec', '')
    metadata('global-modules/docker/metadata.json', name: 'puppetmodules-docker', version: '2.0.0')
    copy_project_config(File.join(@directory, 'global-modules'))
  end

  def test_each_project_uses_its_own_version_when_checked_from_its_root
    scan('.')
    assert_equal 0, @status.exitstatus, @output + @errors
    capture_cli('.', directory: File.join(@directory, 'global-modules'), env: { 'PROJECT_LINT_MODULES_PATH' => '.' })
    assert_equal 0, @status.exitstatus, @output + @errors
  end

  def test_missing_consumer_source_never_falls_back_to_shared_version
    FileUtils.rm(File.join(@directory, 'VERSION'))
    scan('.')
    assert_metadata_error('VERSION', 'version: missing VERSION')
    assert_equal 1, diagnostics(@output, 'project_metadata').size
  end

  def test_version_change_reports_both_own_files_without_fixing_sources_or_metadata
    before = metadata_snapshot
    write_file('VERSION', "4.0.0\n")
    scan('--fix', '.')
    %w[metadata.json modules/profile/metadata.json].each do |path|
      assert_metadata_error(path, 'version: expected 4.0.0 from VERSION; found "3.1.0"')
    end
    assert_equal 2, diagnostics(@output, 'project_metadata').size
    assert_equal before, metadata_snapshot
    assert_equal "4.0.0\n", File.read(File.join(@directory, 'VERSION'))
  end

  def metadata_snapshot
    %w[metadata.json modules/profile/metadata.json global-modules/VERSION
       global-modules/metadata.json global-modules/docker/metadata.json].to_h do |path|
      [path, File.binread(File.join(@directory, path))]
    end
  end
end
