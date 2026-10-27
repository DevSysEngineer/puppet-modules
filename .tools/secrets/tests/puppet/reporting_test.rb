# frozen_string_literal: true

require_relative '../test_helper'

# Native parser exceptions must never become source diagnostics in any report channel.
class PuppetReportingTest < SecretsTest
  def test_console_json_and_junit_never_contain_the_literal
    path = write('sample.pp', "$password = 'synthetic-report-value'\n")
    report = File.join(@directory, 'result.xml')
    scan('--puppet', '--junit', report, path)
    assert_equal 1, @status.exitstatus
    refute_includes File.read(report), 'synthetic-report-value'
    assert_no_disclosure('synthetic-report-value')
    assert_console(path)
  end

  def assert_console(path)
    command = File.expand_path('../../bin/project-tools-secrets', __dir__)
    @out, @err, @status = Open3.capture3(Gem.ruby, command, '--puppet', path)
    assert_equal 1, @status.exitstatus
    assert_includes @out, 'line=1'
    assert_no_disclosure('synthetic-report-value')
  end

  def test_debug_parser_error_is_metadata_only
    path = write('broken.pp', "$password = 'synthetic-malformed")
    command = File.expand_path('../../bin/project-tools-secrets', __dir__)
    @out, @err, @status = Open3.capture3(Gem.ruby, '-d', command, '--puppet', '--json', path)
    assert_equal 2, @status.exitstatus
    assert_no_disclosure('synthetic-malformed')
    assert_includes @out, 'puppet_inspection_failed'
  end

  def test_input_functions_are_not_executed
    path = write('sample.pp', "fail('synthetic-function-must-not-run')\n")
    scan('--puppet', path)
    assert_equal 0, @status.exitstatus
    assert_no_disclosure('synthetic-function-must-not-run')
  end
end
