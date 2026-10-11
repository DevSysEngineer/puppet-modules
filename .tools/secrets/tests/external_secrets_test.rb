# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../../shared/test_support/packages'

# Installed consumers use the same implementation, with no Puppet runtime.
class ExternalSecretsTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('secrets-consumer-')
    consumer_environment
    prepare_environment
    build_install('shared', 'project-tools-shared')
    build_install('secrets', 'project-tools-secrets')
    write('Gemfile', "source 'https://rubygems.org'\ngem 'project-tools-secrets', '= 0.1.0'\n")
    run_success('bundle', 'install', '--local')
  end

  def test_installed_scanner_and_masking_work_from_the_consumer_directory
    write('data/common.yaml', "password: synthetic-consumer\nordinary: unchanged\n")
    command('bundle', 'exec', 'project-tools-secrets', '--json', '--redact', 'copies', 'data')
    assert_equal 1, @status.exitstatus, @output + @errors
    refute_includes @output + @errors, 'synthetic-consumer'
    result = JSON.parse(@output)
    assert result['complete']
    assert_consumer_copy(result)
  end

  def assert_consumer_copy(result)
    clean = read(File.join('copies', result['files'][0]['copy']))
    refute_includes clean, 'synthetic-consumer'
    assert_includes clean, 'ordinary: unchanged'
    assert_includes read('data/common.yaml'), 'synthetic-consumer'
  end

  def test_package_does_not_install_puppet_or_linters
    run_success('bundle', 'exec', 'ruby', '-e',
                "require 'project_tools/secrets'; " \
                'abort if (Bundler.load.specs.map(&:name) & %w[openvox lint-project rubocop]).any?')
  end

  def test_package_contains_runtime_and_usage_but_no_test_or_result_files
    run_success('bundle', 'show', 'project-tools-secrets')
    root = @output.strip
    assert_path_exists File.join(root, 'README.md')
    assert_path_exists File.join(root, 'LICENSE')
    refute_path_exists File.join(root, 'tests')
    refute_path_exists File.join(root, 'results')
  end

  def test_puppet_mode_fails_closed_without_its_optional_parser
    write('sample.pp', "notify { 'synthetic': }\n")
    command('bundle', 'exec', 'project-tools-secrets', '--puppet', '--json', 'sample.pp')
    assert_equal 2, @status.exitstatus, @output + @errors
    assert_includes @output, 'puppet_parser_unavailable'
  end

  def test_installed_puppet_mode_uses_the_same_rules_in_a_consumer_bundle
    configure_puppet
    write('sample.pp', "$password = lookup('example::password', Sensitive[String])\n")
    run_success('bundle', 'exec', 'project-tools-secrets', '--puppet', 'sample.pp')
    write('sample.pp', "$password = Sensitive('synthetic-consumer-value')\n")
    command('bundle', 'exec', 'project-tools-secrets', '--puppet', '--json', 'sample.pp')
    assert_equal 1, @status.exitstatus, @output + @errors
    refute_includes @output + @errors, 'synthetic-consumer-value'
    assert_includes @output, 'puppet_hardcoded_value'
  end

  def configure_puppet
    write('Gemfile', "#{read('Gemfile')}gem 'openvox', '~> 8.0', require: false\ngem 'syslog', require: false\n")
    run_success('bundle', 'install', '--local')
  end
end
