# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require_relative '../../test_support/packages'
require 'rexml/document'
require 'timeout'

# Real native subprocesses keep reporter, loader and signal assertions independent of the coordinator.
module ParallelTestSupport
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('parallel test project ')
    write('Rakefile', File.read(File.join(ROOT, 'Rakefile')))
    write('VERSION', File.read(File.join(ROOT, 'VERSION')))
    FileUtils.mkdir_p(File.join(@project, '.tools/shared'))
    FileUtils.cp_r(File.join(ROOT, '.tools/shared/test_support'), File.join(@project, '.tools/shared'))
  end

  def probe(name, body = 'assert true', path: nil, extra: '')
    bootstrap = File.join(@project, '.tools/shared/test_support/bootstrap')
    write(path || ".tools/sample/tests/#{name.downcase}_test.rb", <<~RUBY)
      require #{bootstrap.dump}
      #{extra}
      class #{name} < Minitest::Test
        def test_contract
          #{body}
        end
      end
    RUBY
  end

  def environment(report: nil, **overrides)
    %w[TEST TESTOPTS TESTOPT TEST_OPTS TEST_OPT MINITEST_REPORTER TM_PID RM_INFO TEAMCITY_VERSION VIM
       PROJECT_TOOLS_TEST_WORKER_CONFIG].to_h { |key| [key, nil] }.merge(
         'MINITEST_REPORTERS_REPORTS_DIR' => report
       ).merge(overrides)
  end

  def run_tests(jobs = '2', report: nil, task: 'test:tools', **overrides)
    arguments = [RbConfig.ruby, Gem.bin_path('rake', 'rake'), task, *Array(jobs && "--jobs=#{jobs}")]
    @output, @errors, @status = Open3.capture3(environment(report: report, **overrides), *arguments, chdir: @project)
  end

  def identities(report)
    Dir[File.join(@project, report, 'TEST-*.xml')].flat_map do |path|
      REXML::XPath.match(REXML::Document.new(File.read(path)), '//testcase').map do |test|
        [test.attributes['classname'], test.attributes['name'],
         %w[failure error skipped].find { |outcome| test.elements[outcome] } || 'passed']
      end
    end.tally
  end

  def assert_success
    assert @status.success?, @output + @errors
  end

  def wait_for_file(path)
    Timeout.timeout(20) { sleep 0.02 until File.exist?(File.join(@project, path)) }
  end
end
