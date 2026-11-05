# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require_relative '../../test_support/packages'
require 'rexml/document'

# An installed consumer deliberately has no project VERSION or Puppet dependency.
module SharedConsumerSupport
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('shared consumer ')
    consumer_environment
    prepare_environment
    build_install('shared', 'project-tools-shared')
    dependencies = %w[project-tools-shared minitest minitest-reporters rake rexml]
    write('Gemfile', "source 'https://rubygems.org'\n#{dependencies.map { |name| "gem '#{name}'" }.join("\n")}\n")
    run_success('bundle', 'install', '--local')
    prepare_tests
  end

  def prepare_tests
    write('Rakefile', <<~RUBY)
      require 'rake/testtask'
      require 'project_tools/shared/test_task'
      tests = Rake::TestTask.new(:test) { |task| task.pattern = 'tests/*_test.rb'; task.warning = false }
      ProjectTools::Shared::TestTask.wrap(tests)
    RUBY
    4.times { |index| write_probe(index) }
  end

  def write_probe(index, assertion = 'assert true')
    write("tests/probe#{index}_test.rb", <<~RUBY)
      require 'project_tools/shared/test_bootstrap'
      class ConsumerProbe#{index} < Minitest::Test
        def test_contract
          refute defined?(Puppet)
          refute ARGV.any? { |argument| argument.start_with?('--jobs') }
          #{assertion}
        end
      end
    RUBY
  end

  def run_suite(jobs, **environment)
    @env.merge!('TEST' => nil, 'TESTOPTS' => '--seed=12345',
                'MINITEST_REPORTERS_REPORTS_DIR' => nil)
    @env.merge!(environment)
    command('bundle', 'exec', 'rake', 'test', '--jobs', jobs.to_s)
  end

  def cases
    Dir[File.join(@project, 'reports/TEST-*.xml')].flat_map do |path|
      REXML::XPath.match(REXML::Document.new(File.read(path)), '//testcase').map do |test|
        [test.attributes['classname'], test.attributes['name'], test.elements['failure']&.text]
      end
    end.sort
  end
end
