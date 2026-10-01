# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'
require_relative 'imports_support'

# Exercise path and Git gemspec selection with independently resolved consumer lockfiles.
class ExternalImportsTest < Minitest::Test
  include ProjectToolsPackageSupport
  include ImportsSupport

  PACKAGES = { 'shared' => 'project-tools-shared', 'lint' => 'lint-project',
               'module-dependencies' => 'project-tools-module-dependencies', 'validate' => 'project-tools-validate',
               'metadata' => 'project-tools-metadata', 'ruby-lint' => 'project-tools-ruby-lint' }.freeze

  def setup
    @project = Dir.mktmpdir('tooling-imports-')
    consumer_environment
    prepare_environment
    write_consumer
  end

  def test_path_consumer_has_its_own_bundle_and_loads_the_monorepo_gemspec
    checkout = File.join(@project, 'global-modules')
    destination = File.join(checkout, '.tools/lint')
    PACKAGES.each { |tool, name| copy_package_source(tool, name, checkout) }
    dependencies = PACKAGES.map do |tool, name|
      "gem '#{name}', path: 'global-modules/.tools/#{tool}', require: false"
    end
    replace_consumer_dependency(dependencies.join("\n"))
    assert_equal File.realpath(destination), @installed
    assert_all_tools
  end

  def test_git_consumer_selects_all_nested_gemspecs_with_a_local_worktree_override
    repository, revision = git_worktree
    dependencies = PACKAGES.values.map { |name| "gem '#{name}', require: false" }.join("\n")
    replace_consumer_dependency(<<~RUBY)
      git #{repository.dump}, ref: #{revision.dump}, glob: '.tools/*/*.gemspec' do
        #{dependencies}
      end
    RUBY
    assert_git_consumer(revision)
  end

  def assert_git_consumer(revision)
    assert_includes read('Gemfile.lock'), revision
    refute @installed.start_with?(ProjectToolsPackageSupport::ROOT)
    assert_all_tools
  end

  def assert_all_tools
    assert_consumer_outcomes
    run_success('bundle', 'exec', 'puppet', 'parser', 'validate', 'manifests/site.pp')
    assert_empty Dir[File.join(@project, '**/*.xml')]
    run_success('bundle', 'exec', 'validate-junit', '.reports/parser.xml', 'manifests/site.pp')
    run_success('bundle', 'exec', 'project-tools-module-dependencies', '--junit', '.reports/dependencies.xml')
    run_success('bundle', 'exec', 'project-tools-metadata', '--junit', '.reports/metadata.xml')
    assert_ruby_tool
  end

  def assert_consumer_outcomes
    lint('manifests')
    assert_equal 0, @status.exitstatus, @output + @errors
    write('manifests/site.pp', "$values = [1] + [2]\n")
    lint('manifests')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @output, 'project_arrays: warning:'
  end

  def lint(*arguments)
    command('bundle', 'exec', 'puppet-lint', '--no-config',
            '--load', File.join(@installed, 'lib/project_lint.rb'),
            '--config', File.join(@installed, 'config/puppet-lint.rc'), *arguments)
  end

  def assert_ruby_tool
    write('.rubocop.yml', "inherit_gem:\n  project-tools-ruby-lint: config/rubocop.yml\n")
    write('example.rb', "# frozen_string_literal: true\n\nputs 1\n")
    run_success('bundle', 'exec', 'rubocop', '--config', '.rubocop.yml', '--cache', 'false', 'example.rb')
  end
end
