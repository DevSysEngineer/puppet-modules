# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../../shared/test_support/packages'
require_relative 'metadata_support'

# Packaged consumers must execute the metadata tool without a source-tree runner.
class ExternalMetadataTest < Minitest::Test
  include ProjectToolsPackageSupport
  include MetadataSupport

  def setup
    @project = Dir.mktmpdir('metadata-consumer-')
    prepare_metadata_project(@project)
    consumer_environment
    prepare_environment
    build_install('shared', 'project-tools-shared')
    build_install('metadata', 'project-tools-metadata')
    write('Gemfile', "source 'https://rubygems.org'\ngem 'project-tools-metadata', '= 0.1.0'\n")
    run_success('bundle', 'install', '--local')
    @env.merge!('PROJECT_METADATA_MODULES_PATH' => 'modules', 'PROJECT_METADATA_PREFIX' => 'example')
    FileUtils.mkdir_p(File.join(@project, 'modules'))
  end

  def test_installed_metadata_has_no_puppet_or_ruby_lint_dependency
    run_success('bundle', 'exec', 'ruby', '-e',
                "require 'project_tools/metadata'; " \
                'abort if (Bundler.load.specs.map(&:name) & %w[openvox lint-project rubocop]).any?')
  end

  def scan(*arguments)
    command('bundle', 'exec', 'project-tools-metadata', *arguments)
  end

  def test_installed_gem_checks_modules_without_manifests
    write('modules/empty/files/example.txt', '')
    scan
    assert_includes metadata_problem('modules/empty/metadata.json')['message'], 'metadata: missing metadata.json'
    write('modules/empty/metadata.json', JSON.generate(project_metadata(name: 'example-empty')))
    scan
    assert_equal 0, @status.exitstatus, @output + @errors
  end

  def test_installed_gem_creates_reports_only_when_requested
    scan
    assert_equal 0, @status.exitstatus, @output + @errors
    refute_path_exists File.join(@project, '.reports')
    scan('--junit', '.reports/metadata.xml')
    assert_equal 0, @status.exitstatus, @output + @errors
    assert_includes read('.reports/metadata.xml'), 'failures="0"'
  end

  def test_installed_gem_executes_partial_autofix_and_preserves_remaining_errors
    write('metadata.json', JSON.generate(project_metadata('0.1.0')))
    write('modules/empty/files/example.txt', '')
    scan('--fix')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes read('metadata.json'), '"version":"7.4.0"'
    assert_equal({ 'name' => 'example-empty', 'version' => '7.4.0' }, JSON.parse(read('modules/empty/metadata.json')))
    assert_includes @output, 'dependencies: expected an array'
    scan('--fix')
    refute_includes @output, ': fixed:'
  end

  def test_installed_gem_checks_the_consumer_root_and_own_version
    write('global-modules/VERSION', "2.0.0\n")
    write('global-modules/metadata.json', JSON.generate(project_metadata('2.0.0', name: 'puppet-modules')))
    write('metadata.json', JSON.generate(project_metadata('2.0.0')))
    scan
    assert_includes metadata_problem['message'], 'version: expected 7.4.0 from VERSION; found "2.0.0"'
  end

  def test_installed_gem_rejects_a_missing_consumer_root_even_with_valid_shared_metadata
    write('global-modules/metadata.json', JSON.generate(project_metadata('2.0.0', name: 'puppet-modules')))
    FileUtils.rm(File.join(@project, 'metadata.json'))
    scan
    assert_includes metadata_problem['message'], 'metadata: missing metadata.json; expected a file in the project root'
  end

  def test_installed_gem_uses_the_module_location_relative_to_the_consumer_root
    FileUtils.mv(File.join(@project, 'modules'), File.join(@project, 'site-modules'))
    @env['PROJECT_METADATA_MODULES_PATH'] = 'site-modules'
    scan
    assert_equal 0, @status.exitstatus, @output + @errors
    write('site-modules/empty/files/example.txt', '')
    scan
    assert_includes metadata_problem('site-modules/empty/metadata.json')['message'], 'metadata: missing metadata.json'
  end

  def test_installed_gem_requires_explicit_configuration_even_with_an_existing_modules_directory
    @env.delete('PROJECT_METADATA_MODULES_PATH')
    scan
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @output, 'modules_path: set PROJECT_METADATA_MODULES_PATH'
  end

  def metadata_problem(path = 'metadata.json')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @output, path
    { 'message' => @output }
  end
end
