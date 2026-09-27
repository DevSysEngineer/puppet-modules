# frozen_string_literal: true

require_relative '../../lint/tests/test_helper'
require_relative '../../lint/tests/installed_gem_support'

# Packaged consumers must execute the metadata hook without a source-tree runner.
class ExternalMetadataTest < Minitest::Test
  include InstalledGemSupport

  def test_installed_gem_checks_modules_even_when_only_manifests_are_selected
    write('modules/empty/files/example.txt', '')
    lint('--json', 'manifests')
    assert_includes metadata_problem('modules/empty/metadata.json')['message'], 'metadata: missing metadata.json'
    write('modules/empty/metadata.json', JSON.generate(project_metadata(name: 'example-empty')))
    lint('manifests')
    assert_equal 0, @status.exitstatus, @output + @errors
  end

  def test_installed_gem_executes_partial_autofix_and_preserves_remaining_errors
    write('metadata.json', JSON.generate(project_metadata('0.1.0')))
    write('modules/empty/files/example.txt', '')
    lint('--fix', '--only-checks=project_metadata', 'manifests')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes read('metadata.json'), '"version":"7.4.0"'
    assert_equal({ 'name' => 'example-empty', 'version' => '7.4.0' }, JSON.parse(read('modules/empty/metadata.json')))
    assert_includes @output, 'dependencies: expected an array'
    lint('--fix', '--only-checks=project_metadata', 'manifests')
    refute_includes @output, ': fixed:'
  end

  def test_installed_gem_checks_the_consumer_root_and_own_version
    write('global-modules/VERSION', "2.0.0\n")
    write('global-modules/metadata.json', JSON.generate(project_metadata('2.0.0', name: 'puppet-modules')))
    write('metadata.json', JSON.generate(project_metadata('2.0.0')))
    lint('--json', 'manifests')
    assert_includes metadata_problem['message'], 'version: expected 7.4.0 from VERSION; found "2.0.0"'
  end

  def test_installed_gem_rejects_a_missing_consumer_root_even_with_valid_shared_metadata
    write('global-modules/metadata.json', JSON.generate(project_metadata('2.0.0', name: 'puppet-modules')))
    FileUtils.rm(File.join(@project, 'metadata.json'))
    lint('--json', 'manifests')
    assert_includes metadata_problem['message'], 'metadata: missing metadata.json; expected a file in the project root'
  end

  def test_installed_gem_uses_the_module_location_relative_to_the_consumer_root
    FileUtils.mv(File.join(@project, 'modules'), File.join(@project, 'site-modules'))
    @env['PROJECT_LINT_MODULES_PATH'] = 'site-modules'
    @env['PROJECT_LINT_MODULEPATH'] = File.join(@project, 'site-modules')
    lint('manifests')
    assert_equal 0, @status.exitstatus, @output + @errors
    write('site-modules/empty/files/example.txt', '')
    lint('--json', 'manifests')
    assert_includes metadata_problem('site-modules/empty/metadata.json')['message'], 'metadata: missing metadata.json'
  end

  def test_installed_gem_requires_explicit_configuration_even_with_an_existing_modules_directory
    @env.delete('PROJECT_LINT_MODULES_PATH')
    lint('--json', 'manifests')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes JSON.parse(@output).flatten.first['message'], 'modules_path: set PROJECT_LINT_MODULES_PATH'
  end

  def metadata_problem(path = 'metadata.json')
    assert_equal 1, @status.exitstatus, @output + @errors
    problems = JSON.parse(@output).flatten
    assert_equal([path], problems.map { |problem| problem['path'] })
    problems.first
  end
end
