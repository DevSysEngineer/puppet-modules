# frozen_string_literal: true

require_relative '../../shared/test_support/packages'

# Build a gem and exercise it through a separate, offline consumer bundle.
module InstalledGemSupport
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('lint-consumer-')
    consumer_environment
    prepare_environment
    install_gem
    prepare_bundle
    prepare_project
  end

  def reverse_modulepath
    @env['PROJECT_TOOLS_MODULEPATH'] = @env.fetch('PROJECT_TOOLS_MODULEPATH').split(':').reverse.join(':')
  end

  def install_gem
    build_install('shared', 'project-tools-shared')
    build_install('lint', 'lint-project')
  end

  def prepare_bundle
    write('Gemfile', <<~RUBY)
      source 'https://rubygems.org'
      gem 'lint-project', '= 0.2.0', require: false
    RUBY
    run_success('bundle', 'install', '--local')
    run_success('bundle', 'info', '--path', 'lint-project')
    @installed = @output.strip
    @env['BUNDLE_FROZEN'] = 'true'
  end

  def prepare_project
    write('.puppet-lint.rc', "--ignore-paths=dependencies/*,vendor/*,spec/*\n")
    write('manifests/site.pp', "$values = concat([1], [2])\n")
    write_module('profile', 'class profile (String $value) {}')
    write('dependencies/shared/manifests/init.pp', 'class shared (String $value) {}')
    write('spec/invalid.pp', "$values = [1] + [2]\n")
    @env['PROJECT_TOOLS_MODULEPATH'] = [File.join(@project, 'modules'), File.join(@project, 'dependencies')].join(':')
  end

  def write_module(name, code)
    write("modules/#{name}/manifests/init.pp", code)
  end

  def lint(*arguments)
    command('bundle', 'exec', 'puppet-lint', '--no-config',
            '--load', File.join(@installed, 'lib/project_lint.rb'),
            '--config', File.join(@installed, 'config/puppet-lint.rc'),
            '--config', '.puppet-lint.rc', *arguments)
  end
end
