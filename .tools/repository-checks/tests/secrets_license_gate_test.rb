# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'

# The installed CLI and the standard Rake prerequisite reject the same synthetic license.
class SecretsLicenseGateTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('license-gate-')
    consumer_environment
    prepare_environment
    build_install('shared', 'project-tools-shared')
    build_install('secrets', 'project-tools-secrets')
    write_bundle
    write('Rakefile', File.read(File.join(ROOT, 'Rakefile')))
    write('.tools/shared/tests/probe_test.rb', "File.write('tests-ran', 'yes')\n")
  end

  def write_bundle
    write('Gemfile', <<~RUBY)
      source 'https://rubygems.org'
      gem 'project-tools-secrets', '= 0.3.0'
      gem 'openvox', '~> 8.0'
      gem 'syslog'
      gem 'rake'
    RUBY
    run_success('bundle', 'install', '--local')
  end

  def test_license_failure_blocks_standard_tests_and_matches_direct_cli
    write('sample.pp', "$license_key = lookup('example::license_key')\n")
    run_success('bundle', 'exec', 'rake', 'secrets:puppet')
    write('sample.pp', "$license_key = 'synthetic-gate-license'\n")
    command('bundle', 'exec', 'project-tools-secrets', '--puppet', '--json', 'sample.pp')
    assert_gate_failure
    command('bundle', 'exec', 'rake', 'test')
    assert_gate_failure
    refute_path_exists File.join(@project, 'tests-ran')
  end

  def assert_gate_failure
    assert_equal 1, @status.exitstatus, @output + @errors
    refute_includes @output + @errors, 'synthetic-gate-license'
  end

  def guide_example(heading)
    guide = File.read(File.join(ROOT, '.tools/secrets/README.md'))
    section = guide.split("### #{heading}\n", 2).fetch(1).split(/^### /, 2).first
    section.match(/^```ruby\n(.*?)^```/m)[1]
  end

  def documented_consumer
    checkout = File.join(@project, 'global-modules')
    %w[shared secrets].each { |tool| copy_package_source(tool, "project-tools-#{tool}", checkout) }
    write('Gemfile', guide_example('Installeer in de eigen bundle'))
    run_success('bundle', 'install', '--local')
    rake = guide_example('Koppel de Puppet-controle aan eigen taken')
    write('Rakefile', "#{rake}\n#{consumer_tasks}")
  end

  def consumer_tasks
    <<~RUBY
      task :diagnostics do
        File.write('diagnostics-ran', 'yes')
      end
      task test: :diagnostics do
        File.write('tests-ran', 'yes')
      end
      task default: :test
    RUBY
  end

  def test_documented_bundle_and_rake_run_the_gate_before_other_prerequisites
    documented_consumer
    write('modules/profile/manifests/init.pp', "$license_key = lookup('example::license_key')\n")
    run_success('bundle', 'exec', 'rake')
    assert_equal 'yes', read('diagnostics-ran')
    assert_equal 'yes', read('tests-ran')
    %w[diagnostics-ran tests-ran].each { |name| FileUtils.rm(File.join(@project, name)) }
    write('modules/profile/manifests/init.pp', "$license_key = 'synthetic-gate-license'\n")
    command('bundle', 'exec', 'rake')
    assert_gate_failure
    assert_downstream_withheld
  end

  def test_documented_rake_preserves_parser_errors_and_rejects_empty_selection
    documented_consumer
    command('bundle', 'exec', 'rake', 'test')
    assert_equal 1, @status.exitstatus
    assert_downstream_withheld
    write('modules/profile/manifests/init.pp', "class {\n")
    command('bundle', 'exec', 'rake', 'test')
    assert_equal 2, @status.exitstatus
    assert_downstream_withheld
  end

  def assert_downstream_withheld
    refute_path_exists File.join(@project, 'diagnostics-ran')
    refute_path_exists File.join(@project, 'tests-ran')
  end
end
