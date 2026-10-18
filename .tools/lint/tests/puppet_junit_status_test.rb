# frozen_string_literal: true

require_relative 'test_helper'
require 'project_lint/puppet_junit'
require 'stringio'

# The optional result status reports evidence; the native CLI still decides whether the job fails.
class PuppetJunitStatusTest < Minitest::Test
  def result(data, path)
    ProjectLint::PuppetJunit.run(['--result-status', path], input: StringIO.new(data),
                                                            console: StringIO.new, errors: StringIO.new)
  end

  def finding(kind)
    { path: 'site.pp', check: 'example', kind: kind, message: 'Synthetic finding', line: 1, column: 1 }
  end

  def test_active_findings_return_a_distinct_status_after_writing_the_report
    Dir.mktmpdir('junit-result-') do |directory|
      path = File.join(directory, 'report.xml')
      %w[warning error].each do |kind|
        assert_equal 10, result(JSON.generate([[finding(kind)]]), path)
        assert_includes File.read(path), 'failures="1"'
      end
    end
  end

  def test_clean_fixed_and_ignored_results_do_not_signal_active_findings
    Dir.mktmpdir('junit-result-') do |directory|
      path = File.join(directory, 'report.xml')
      assert_equal 0, result('[[], []]', path)
      assert_equal 0, result(JSON.generate([[finding('fixed'), finding('ignored')]]), path)
    end
  end

  def test_empty_malformed_and_unwritable_reports_remain_conversion_errors
    Dir.mktmpdir('junit-result-') do |directory|
      path = File.join(directory, 'report.xml')
      ['', '[]', '[[{'].each { |data| assert_equal 1, result(data, path) }
      assert_equal 1, result(JSON.generate([[finding('warning')]]), directory)
    end
  end
end
