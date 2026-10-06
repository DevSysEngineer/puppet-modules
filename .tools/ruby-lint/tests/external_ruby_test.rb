# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'
require 'timeout'

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
    assert_empty @output
    assert_includes @errors, 'Layout/SpaceAroundOperators'
    assert_includes read('rubocop.xml'), "<failure type='Layout/SpaceAroundOperators'"
  end

  def rubocop_report
    command('bundle', 'exec', 'rubocop', '--config', '.rubocop.yml', '--cache', 'false',
            '--stderr', '--format', 'progress', '--format', 'junit', '--out', 'rubocop.xml', 'example.rb')
  end

  def test_native_progress_is_visible_before_the_scan_finishes
    write('.rubocop.yml', "inherit_gem:\n  project-tools-ruby-lint: config/rubocop.yml\n")
    write('example.rb', "# frozen_string_literal: true\n\nputs 1\n")
    write('wait.rb', native_progress_hook)
    command = %w[bundle exec rubocop --cache false --stderr --require ./wait.rb example.rb]
    Open3.popen3(@env, *command, chdir: @project, unsetenv_others: true) do |input, output, errors, process|
      Timeout.timeout(20) { assert_live_progress(input, output, errors, process) }
    end
  end

  def native_progress_hook
    <<~RUBY
      require 'rubocop'
      RuboCop::Formatter::ProgressFormatter.prepend(Module.new do
        def started(files)
          super
          STDIN.gets
        end
      end)
    RUBY
  end

  def assert_live_progress(input, output, errors, process)
    assert_includes errors.readline, 'Inspecting 1 file'
    assert process.alive?
    input.puts 'continue'
    input.close
    assert_empty output.read
    diagnostic = errors.read
    assert process.value.success?, diagnostic
  end
end
