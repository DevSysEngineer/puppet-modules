# frozen_string_literal: true

require_relative 'markdown_helper'

# Public reporting must never publish source excerpts.
class SecretsMarkdownReportTest < SecretsMarkdownTestCase
  def test_uncertain_indentation_reports_only_metadata
    path = write('sample.md', "    password = synthetic-head\n   synthetic-tail\n")
    report = File.join(@directory, 'report.xml')
    scan('--junit', report, path)
    assert_equal 2, @status.exitstatus
    refute @report['complete']
    assert_no_disclosure('synthetic-head', 'synthetic-tail')
    refute_includes File.read(report), 'synthetic-head'
    refute_includes File.read(report), 'synthetic-tail'
  end

  def test_cli_reports_and_debug_mode_never_include_source_values
    path = write('sample.md', "Uitleg `password = join(['synthetic-cli-value'` einde.\n")
    report = File.join(@directory, 'report.xml')
    scan('--junit', report, path)
    assert_complete_scan
    assert_masked('synthetic-cli-value')
    refute_includes File.read(report), 'synthetic-cli-value'
    assert_debug_output(path)
  end

  def assert_debug_output(path)
    command = File.expand_path('../bin/project-tools-secrets', __dir__)
    @out, @err, @status = Open3.capture3(Gem.ruby, '-e', '$DEBUG = true; load ARGV.shift', command, path)
    assert_equal 1, @status.exitstatus
    assert_no_disclosure('synthetic-cli-value')
    refute_includes @err, 'Exception'
  end
end
