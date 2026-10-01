# frozen_string_literal: true

require_relative '../test_support/bootstrap'
require_relative '../test_support/packages'
require 'rexml/document'

# All tool helpers share one reporter bootstrap and preserve other producers' reports.
class SharedBootstrapTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('joint-tooltests-')
    @reports = File.join(@project, 'reports')
    write('Rakefile', File.read(File.join(ROOT, 'Rakefile')))
    write('reports/TEST-old.xml', '<stale/>')
    write('reports/project-tools-module-dependencies-report.xml', '<preserved/>')
  end

  def test_joint_run_initializes_once_and_runs_each_owner
    %w[lint shared module-dependencies validate metadata ruby-lint repository-checks].each_with_index do |tool, index|
      write_probe(tool, index)
    end
    environment = { 'MINITEST_REPORTERS_REPORTS_DIR' => @reports, 'TEST' => nil, 'TESTOPTS' => nil }
    output, errors, status = Open3.capture3(environment, RbConfig.ruby, Gem.bin_path('rake', 'rake'),
                                            'test', chdir: @project)
    assert status.success?, output + errors
    assert_equal 1, output.scan('Emptying ').length
    assert_joint_reports
  end

  def write_probe(tool, index)
    bootstrap = File.join(ROOT, '.tools/shared/test_support/bootstrap')
    write(".tools/#{tool}/tests/nested/probe_test.rb", <<~RUBY)
      require #{bootstrap.dump}
      class ToolProbe#{index} < Minitest::Test
        def test_tool_contract
          assert true
        end
      end
    RUBY
  end

  def assert_joint_reports
    assert_equal '<preserved/>', read('reports/project-tools-module-dependencies-report.xml')
    refute_path_exists File.join(@reports, 'TEST-old.xml')
    reports = Dir[File.join(@reports, 'TEST-*.xml')]
    assert_equal 7, reports.length
    reports.each do |path|
      document = REXML::Document.new(File.read(path))
      assert_equal 1, REXML::XPath.match(document, '//testcase').length
    end
  end
end
