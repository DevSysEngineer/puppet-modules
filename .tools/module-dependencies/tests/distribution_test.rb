# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../../shared/test_support/packages'

# Exercise the independent package boundary with fresh, offline consumer lockfiles.
class DependencyDistributionTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('dependency-consumer-')
    consumer_environment
    prepare_environment
    build_install('shared', 'project-tools-shared')
    build_install('module-dependencies', 'project-tools-module-dependencies')
    prepare_metadata
  end

  def prepare_metadata
    write('metadata.json', JSON.generate({ dependencies: [{ name: 'example-library', version_requirement: '>= 2' }] }))
    write('modules/library/metadata.json', JSON.generate({ name: 'example-library', version: '2.0.0', dependencies: [],
                                                           author: 'example', source: 'https://example.org/modules',
                                                           license: 'Apache-2.0' }))
    @env['PROJECT_TOOLS_MODULEPATH'] = File.join(@project, 'modules')
  end

  def bundle_with(dependencies)
    write('Gemfile', "source 'https://rubygems.org'\n#{dependencies}\n")
    run_success('bundle', 'install', '--local')
    @env['BUNDLE_FROZEN'] = 'true'
  end

  def assert_independent_runtime
    run_success('bundle', 'exec', 'ruby', '-e', <<~RUBY)
      forbidden = %w[lint-project puppet-lint rubocop minitest minitest-reporters rake]
      abort 'lint dependency leaked' unless (Bundler.load.specs.map(&:name) & forbidden).empty?
      abort 'JSON API incompatible' unless Gem.loaded_specs.fetch('json').version < Gem::Version.new('3')
      require 'project_tools/module_dependencies/cli'
      abort 'lint loaded' if defined?(PuppetLint) || defined?(RuboCop)
    RUBY
    assert_consumer_scan
  end

  def stable_console(output)
    output.lines.reject { |line| line.start_with?('Duration:', 'JUnit written:') }
  end

  def assert_consumer_scan
    run_success('bundle', 'exec', 'project-tools-module-dependencies')
    refute_path_exists File.join(@project, 'reports')
    console = @output
    run_success('bundle', 'exec', 'project-tools-module-dependencies', '--junit', 'reports/dependencies.xml')
    assert_equal stable_console(console), stable_console(@output)
    assert_includes @output, 'Module metadata assessed: 1.'
    write('metadata.json', JSON.generate({ dependencies: [{ name: 'example-library', version_requirement: '< 2' }] }))
    command('bundle', 'exec', 'project-tools-module-dependencies', '--junit', 'reports/dependencies.xml')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes read('reports/dependencies.xml'), 'version_mismatch'
  end

  def test_built_gems_work_without_checkout_or_lint_dependencies
    bundle_with("gem 'project-tools-module-dependencies', '= 0.1.0', require: false")
    assert_independent_runtime
    run_success('bundle', 'info', '--path', 'project-tools-shared')
    assert File.realpath(@output.strip).start_with?(File.realpath(@gem_home))
  end

  def copy_dependency_sources
    checkout = File.join(@project, 'global-modules')
    copy_package_source('shared', 'project-tools-shared', checkout)
    copy_package_source('module-dependencies', 'project-tools-module-dependencies', checkout)
  end

  def test_path_consumer_resolves_shared_from_its_explicit_source
    copy_dependency_sources
    bundle_with(<<~RUBY)
      gem 'project-tools-shared', path: 'global-modules/.tools/shared', require: false
      gem 'project-tools-module-dependencies', path: 'global-modules/.tools/module-dependencies', require: false
    RUBY
    assert_independent_runtime
  end

  def test_gem_payloads_exclude_repository_support_and_have_explicit_dependencies
    %w[project-tools-shared project-tools-module-dependencies].each do |name|
      spec = Gem::Package.new(File.join(@project, "#{name}.gem")).spec
      assert_includes spec.files, 'README.md'
      assert_includes spec.files, 'LICENSE'
      assert_empty spec.files.grep(/(?:tests|test_support|results|Gemfile|\.lock)/)
      assert_empty spec.dependencies.map(&:name) & %w[lint-project puppet-lint rubocop minitest minitest-reporters]
    end
  end

  def test_missing_unpublished_shared_source_fails_without_checkout_fallback
    copy_dependency_sources
    @env.merge!('GEM_HOME' => File.join(@project, 'empty-gems'), 'GEM_PATH' => Gem.path.join(File::PATH_SEPARATOR))
    write('Gemfile', <<~RUBY)
      source 'https://rubygems.org'
      gem 'project-tools-module-dependencies', path: 'global-modules/.tools/module-dependencies', require: false
    RUBY
    command(RbConfig.ruby, Gem.bin_path('bundler', 'bundle'), 'install', '--local')
    refute @status.success?
    assert_includes @output + @errors, 'project-tools-shared'
  end
end
