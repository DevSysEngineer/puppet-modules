# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'

# Exercise the Ruby package without installing Puppet tooling.
class ExternalRubyTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('ruby-lint-consumer-')
    consumer_environment
    prepare_environment
    build_install('ruby-lint', 'project-tools-ruby-lint')
    write('Gemfile', "source 'https://rubygems.org'\ngem 'project-tools-ruby-lint', '= 0.1.0'\n")
    run_success('bundle', 'install', '--local')
    run_success('bundle', 'exec', 'ruby', '-e',
                'abort if (Bundler.load.specs.map(&:name) & %w[lint-project openvox project-tools-shared]).any?')
  end

  def test_rubocop_and_its_profile_are_supplied_by_the_installed_gem
    write('.rubocop.yml', <<~YAML)
      inherit_gem:
        project-tools-ruby-lint: config/rubocop.yml
    YAML
    write('example.rb', "# frozen_string_literal: true\n\nvalue = 1\nputs value\n")
    rubocop_report
    assert_clean_ruby_report
    write('example.rb', "# frozen_string_literal: true\n\nvalue=1\nputs value\n")
    rubocop_report
    assert_failed_ruby_report
  end

  def assert_clean_ruby_report
    assert @status.success?, @output + @errors
    assert_includes read('rubocop.xml'), '<testsuites>'
    refute_includes read('rubocop.xml'), '<failure '
  end

  def assert_failed_ruby_report
    refute @status.success?
    assert_includes @output, 'Layout/SpaceAroundOperators'
    assert_includes read('rubocop.xml'), "<failure type='Layout/SpaceAroundOperators'"
  end

  def rubocop_report
    command('bundle', 'exec', 'rubocop', '--config', '.rubocop.yml', '--cache', 'false',
            '--format', 'progress', '--format', 'junit', '--out', 'rubocop.xml', 'example.rb')
  end
end
