# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'
require 'rexml/document'
require 'yaml'
require_relative 'catalog_reporting_support'

# Temporary consumer setup is shared by the entry point and Hiera regressions below.
module CatalogConsumerSupport
  include ProjectToolsPackageSupport
  include CatalogConsumerReportingSupport

  SYNTHETIC_VALUE = 'synthetic-catalog-test-only'

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
    %w[lib bin].each { |path| FileUtils.cp_r(File.join(ROOT, '.tools', 'catalog', path), destination) }
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

  def invoke(entry, report: false, options: [])
    arguments = if entry == :rake
                  ['rake', '-f', File.join(@library, 'Rakefile'),
                   report ? 'catalog:compile[catalog.xml]' : 'catalog:compile']
                else
                  [File.join(@library, '.tools', 'catalog', 'bin', 'project-tools-catalog'),
                   *(['--junit', 'catalog.xml'] if report)]
                end
    command('bundle', 'exec', *arguments, *options, directory: File.join(@project, 'elsewhere'))
  end

  def assert_log_status(status)
    assert_equal [status], @output.scan(/^\[(PASSED|FAILED|ERROR|SKIPPED)\] Puppet catalogs$/).flatten
    assert_equal 1, @output.scan('[START] Puppet catalogs').size
    refute_includes @output, 'Compiled definitions:'
    refute_match(/Compiled \d+ resources\./, @output)
  end

  def suite
    REXML::Document.new(read('elsewhere/catalog.xml')).root.elements['testsuite']
  end

  def prepare_modulepath
    sample_module('modules', 'profile', body: 'include sample', scenario: 'combined/default')
    sample_module('modules', 'sample')
    write('global-modules/sample/manifests/init.pp', "class sample { fail('shadowed module') }")
    @env['PROJECT_TOOLS_MODULEPATH'] = [File.join(@project, 'modules'), @library].join(File::PATH_SEPARATOR)
  end

  def consumer_hiera(name)
    config = { 'version' => 5, 'defaults' => { 'datadir' => 'data', 'data_hash' => 'yaml_data' },
               'hierarchy' => [{ 'name' => 'Test data', 'path' => 'common.yaml' }] }
    write("modules/#{name}/tests/hiera/hiera.yaml", YAML.dump(config))
    key = 'sample::password'
    data = { 'lookup_options' => { key => { 'convert_to' => 'Sensitive' } }, key => SYNTHETIC_VALUE }
    write("modules/#{name}/tests/hiera/data/common.yaml", YAML.dump(data))
  end

  def assert_report_preserved(entry)
    write('elsewhere/catalog.xml', '<previous/>')
    invoke(entry)
    assert @status.success?, @output + @errors
    assert_equal '<previous/>', read('elsewhere/catalog.xml')
  end
end
