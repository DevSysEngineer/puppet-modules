# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'
require 'rexml/document'

# Exercise the actual entry points from an independent bundle and a relocated checkout.
class CatalogIntegrationTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('catalog consumer ')
    consumer_environment
    prepare_environment
    @library = File.join(@project, 'global-modules')
    copy_runner
    FileUtils.cp(File.join(ROOT, 'Rakefile'), File.join(@library, 'Rakefile'))
    copy_package_source('shared', 'project-tools-shared', @library)
    install_bundle
    sample_module('global-modules', 'sample')
    write('elsewhere/.keep', '')
  end

  def copy_runner
    destination = File.join(@library, '.tools', 'catalog')
    FileUtils.mkdir_p(destination)
    %w[lib compile.rb].each { |path| FileUtils.cp_r(File.join(ROOT, '.tools', 'catalog', path), destination) }
  end

  def install_bundle
    write('Gemfile', <<~RUBY)
      source 'https://rubygems.org'
      gem 'project-tools-shared', path: 'global-modules/.tools/shared'
      gem 'openvox', '~> 8.29'
      gem 'json', '< 3'
      gem 'syslog', '~> 0.4'
      gem 'rake'
    RUBY
    run_success('bundle', 'install', '--local')
    @env.merge!('BUNDLE_FROZEN' => 'true', 'BUNDLE_GEMFILE' => File.join(@project, 'Gemfile'))
  end

  def sample_module(base, name, body: '', scenario: 'default')
    write("#{base}/#{name}/manifests/init.pp", "class #{name} { #{body} }\n")
    write("#{base}/#{name}/tests/manifests/#{scenario}.pp", "include #{name}\n")
    write("#{base}/#{name}/tests/facts/synthetic.json", '{}')
  end

  def invoke(entry, report: false)
    arguments = if entry == :rake
                  ['rake', '-f', File.join(@library, 'Rakefile'),
                   report ? 'catalog:compile[catalog.xml]' : 'catalog:compile']
                else
                  ['ruby', File.join(@library, '.tools', 'catalog', 'compile.rb'),
                   *(['--junit', 'catalog.xml'] if report)]
                end
    command('bundle', 'exec', *arguments, directory: File.join(@project, 'elsewhere'))
  end

  def suite
    REXML::Document.new(read('elsewhere/catalog.xml')).root.elements['testsuite']
  end

  def test_default_checkout_selection_is_independent_of_current_directory_for_both_entry_points
    sample_module('elsewhere', 'decoy', body: "fail('wrong directory')")
    %i[cli rake].each do |entry|
      invoke(entry, report: true)
      assert @status.success?, @output + @errors
      assert_counts(%w[1 0 0])
      assert_equal 'sample/default [synthetic]', suite.elements['testcase'].attributes['name']
      assert_report_preserved(entry)
    end
  end

  def assert_report_preserved(entry)
    write('elsewhere/catalog.xml', '<previous/>')
    invoke(entry)
    assert @status.success?, @output + @errors
    assert_equal '<previous/>', read('elsewhere/catalog.xml')
  end

  def assert_counts(expected)
    assert_equal(expected, %w[tests failures errors].map { |key| suite.attributes[key] })
  end

  def test_consumer_modulepath_discovers_new_tests_and_uses_the_same_order_for_compilation
    prepare_modulepath
    %i[cli rake].each do |entry|
      invoke(entry, report: true)
      assert @status.success?, @output + @errors
      assert_counts(%w[2 0 0])
      assert_equal(['profile/combined/default [synthetic]', 'sample/default [synthetic]'],
                   suite.get_elements('testcase').map { |item| item.attributes['name'] })
    end
  end

  def prepare_modulepath
    sample_module('modules', 'profile', body: 'include sample', scenario: 'combined/default')
    sample_module('modules', 'sample')
    write('global-modules/sample/manifests/init.pp', "class sample { fail('shadowed module') }")
    @env['PROJECT_TOOLS_MODULEPATH'] = [File.join(@project, 'modules'), @library].join(File::PATH_SEPARATOR)
  end

  def test_failure_and_error_statuses_reach_ci_without_hiding_successful_modules
    sample_module('global-modules', 'failure', body: "notify { 'same': } notify { 'same': }")
    write('global-modules/invalid/tests/facts/invalid.json', '[]')
    write('global-modules/invalid/tests/manifests/default.pp', "notify { 'valid syntax': }")
    %i[cli rake].each do |entry|
      [false, true].each { |report| assert_mixed_results(entry, report: report) }
      assert_counts(%w[3 1 1])
    end
  end

  def assert_mixed_results(entry, report:)
    invoke(entry, report: report)
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @output, 'Duplicate declaration'
    assert_includes @output, 'Expected a JSON object of facts'
    assert_includes @output, 'sample/default [synthetic]'
  end
end
