# frozen_string_literal: true

require_relative 'test_helper'
require 'rexml/document'

# Verify the packaged CLI against synthetic manifests in an independent consumer bundle.
class ExternalValidateTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('validate-consumer-')
    consumer_environment
    prepare_environment
    build_install('shared', 'project-tools-shared')
    build_install('validate', 'project-tools-validate')
    prepare_bundle("gem 'project-tools-validate', '= 0.1.0', require: false")
    write('manifests/site.pp', "$value = 'synthetic'\n")
    write('modules/profile/manifests/init.pp', 'class profile {}')
  end

  def prepare_bundle(dependencies)
    @env.delete('BUNDLE_FROZEN')
    FileUtils.rm_f(File.join(@project, 'Gemfile.lock'))
    write('Gemfile', "source 'https://rubygems.org'\n#{dependencies}\n")
    run_success('bundle', 'install', '--local')
    run_success('bundle', 'info', '--path', 'project-tools-validate')
    @installed = @output.strip
    @env['BUNDLE_FROZEN'] = 'true'
  end

  def test_native_failures_keep_later_results_and_source_unchanged
    prepare_invalid_and_valid_manifests
    command('bundle', 'exec', 'validate-junit', 'reports/validate-report.xml', *@paths)
    refute @status.success?, @output + @errors
    assert_mixed_results(report_suite)
    assert_includes @output, 'Syntax error'
    assert_equal "$value = [\n", read(@paths[0])
    assert_equal "fail('synthetic validation input')\n", read(@paths[1])
    assert_empty Dir[File.join(@project, '*.xml')]
  end

  def prepare_invalid_and_valid_manifests
    bad = 'manifests/invalid.pp'
    good = 'manifests/valid & é.pp'
    missing = 'manifests/missing.pp'
    write(bad, "$value = [\n")
    # Parsing must not evaluate this call or compile a catalog.
    write(good, "fail('synthetic validation input')\n")
    @paths = [bad, good, missing]
  end

  def report_suite
    REXML::Document.new(read('reports/validate-report.xml')).root.elements['testsuite']
  end

  def assert_mixed_results(suite)
    assert_equal 'validate', suite.attributes['name']
    assert_equal(%w[3 1 1], %w[tests failures errors].map { |key| suite.attributes[key] })
    cases = suite.get_elements('testcase').to_h { |item| [item.attributes['name'], item] }
    assert_equal @paths, cases.keys
    assert_case_outcomes(*cases.values)
  end

  def assert_case_outcomes(bad, good, missing)
    assert_includes bad.elements['failure'].text, 'Syntax error'
    assert_nil good.elements['failure']
    assert_nil good.elements['error']
    assert missing.elements['error']
  end

  def test_clean_run_replaces_failure_report_and_does_not_overwrite_other_reports
    report = 'reports/validate-report.xml'
    write(report, '<stale-failure/>')
    other = 'reports/puppet-lint-report.xml'
    write(other, 'synthetic other report')
    run_success('bundle', 'exec', 'validate-junit', report, 'manifests/site.pp',
                'modules/profile/manifests/init.pp')
    suite = report_suite
    assert_equal(%w[2 0 0], %w[tests failures errors].map { |key| suite.attributes[key] })
    assert_equal 'synthetic other report', read(other)
    refute File.exist?(File.join(@installed, 'results'))
  end

  def test_built_package_loads_without_lint_or_project_configuration
    run_success('bundle', 'exec', 'ruby', '-e', <<~RUBY)
      require 'project_tools/validate'
      forbidden = %w[lint-project puppet-lint rubocop project-tools-module-dependencies minitest minitest-reporters rake]
      abort 'unrelated tool dependency' unless (Bundler.load.specs.map(&:name) & forbidden).empty?
      abort 'lint loaded' if defined?(ProjectLint) || defined?(PuppetLint) || defined?(RuboCop)
      abort 'JSON API incompatible' unless Gem.loaded_specs.fetch('json').version < Gem::Version.new('3')
    RUBY
    %w[VERSION metadata.json .puppet-lint.rc].each { |path| refute_path_exists File.join(@project, path) }
    assert_package_contents
  end

  def assert_package_contents
    spec = Gem::Package.new(File.join(@project, 'project-tools-validate.gem')).spec
    assert_equal ['validate-junit'], spec.executables
    assert_includes spec.files, 'LICENSE'
    assert_includes spec.files, 'README.md'
    assert_empty spec.files.grep(/(?:tests|test_support|results|Gemfile|\.lock)/)
    assert File.realpath(@installed).start_with?(File.realpath(@gem_home))
  end

  def test_path_consumer_uses_explicit_shared_and_validator_sources
    checkout = File.join(@project, 'global-modules')
    copy_package_source('shared', 'project-tools-shared', checkout)
    copy_package_source('validate', 'project-tools-validate', checkout)
    prepare_bundle(<<~RUBY)
      gem 'project-tools-shared', path: 'global-modules/.tools/shared', require: false
      gem 'project-tools-validate', path: 'global-modules/.tools/validate', require: false
    RUBY
    run_success('bundle', 'exec', 'validate-junit', 'reports/validate-report.xml', 'manifests/site.pp')
    assert_equal '0', report_suite.attributes['failures']
    assert_equal File.realpath(File.join(checkout, '.tools/validate')), File.realpath(@installed)
  end
end
