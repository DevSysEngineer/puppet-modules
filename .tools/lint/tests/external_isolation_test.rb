# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'

# Puppet lint must not install other independent tools.
class ExternalLintIsolationTest < Minitest::Test
  include InstalledGemSupport

  def test_puppet_lint_loads_without_development_dependencies_or_loading_rubocop
    script = "abort 'development dependency leaked' unless " \
             '(Bundler.load.specs.map(&:name) & ' \
             '%w[rubocop project-tools-metadata project-tools-validate metadata-json-lint rake minitest]).empty?; ' \
             "require 'project_lint'; abort 'RuboCop loaded by Puppet-lint' if defined?(RuboCop)"
    run_success('bundle', 'exec', 'ruby', '-e', script)
    lint('manifests')
    assert @status.success?, @output + @errors
  end

  def test_lint_without_version_or_metadata_and_fix_never_rewrites_metadata
    refute_path_exists File.join(@project, 'VERSION')
    refute_path_exists File.join(@project, 'metadata.json')
    lint('manifests')
    assert @status.success?, @output + @errors
  end

  def test_fix_never_rewrites_metadata
    write('VERSION', "7.4.0\n")
    write('metadata.json', '{"version":"0.1.0"}')
    write('modules/profile/metadata.json', '{"version":"0.1.0"}')
    write('manifests/site.pp', "$values = [1] + [2]\n")
    lint('--fix', 'manifests')
    assert @status.success?, @output + @errors
    assert_equal '{"version":"0.1.0"}', read('metadata.json')
    assert_equal '{"version":"0.1.0"}', read('modules/profile/metadata.json')
  end

  def test_metadata_is_not_registered_as_a_lint_check
    lint('--list-checks')
    refute_includes @output, 'project_metadata'
  end
end
