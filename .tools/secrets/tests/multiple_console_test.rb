# frozen_string_literal: true

require_relative 'test_helper'

# Multiple diagnostics must survive each other, including failures after the scan.
class SecretsMultipleConsoleTest < SecretsTest
  def finding_inputs
    first = write('a-first.pp', "$password = 'synthetic-first-password'\n\n" \
                                "$database_password = 'synthetic-second-password'\n")
    last = write('z-last.pp', "$password = 'synthetic-last-password'\n")
    [first, last]
  end

  def error_inputs
    invalid = write('invalid.pp', "notify { 'unfinished':\n")
    [File.join(@input, 'missing.pp'), invalid]
  end

  def console(*arguments)
    output = StringIO.new
    @code = ProjectTools::Secrets.run(['--puppet', *arguments], output: output)
    @console = output.string
    %w[synthetic-first-password synthetic-second-password synthetic-last-password].each do |value|
      refute_includes @console, value
    end
  end

  def assert_findings(first, last)
    assert_includes @console, 'Findings: 3 | 3 possible secret values | 0 sensitivity indicators'
    diagnostics = @console.lines.grep(/possible secret value:/).map(&:strip)
    explanation = 'possible secret value: A sensitive Puppet setting or Sensitive wrapper ' \
                  'contains a hardcoded value. (puppet_hardcoded_value)'
    assert_equal ["#{first} | line=1 | #{explanation}", "#{first} | line=3 | #{explanation}",
                  "#{last} | line=1 | #{explanation}"], diagnostics
  end

  def assert_source_errors(missing, invalid)
    assert_includes @console, "#{missing}: error: The path could not be read; " \
                              'check that it exists and is accessible. (unreadable_path)'
    assert_includes @console, "#{invalid}: error: Puppet syntax could not be inspected; check the manifest locally. " \
                              '(puppet_inspection_failed)'
  end

  def assert_console(*messages)
    messages.each { |message| assert_includes @console, message }
  end

  def test_multiple_values_in_one_file_and_across_files_are_all_reported_in_order
    first, last = finding_inputs
    console(last, first)
    assert_equal 1, @code
    assert_console('[FAILED] Sensitive data scan', 'Files: 2 selected | 2 complete | 0 incomplete', 'Errors: 0')
    assert_findings(first, last)
  end

  def test_multiple_source_errors_are_reported_without_stopping_at_the_first
    missing, invalid = error_inputs
    console(missing, invalid)
    assert_equal 2, @code
    assert_console('[ERROR] Sensitive data scan', 'Execution: incomplete')
    assert_includes @console, 'Files: 2 selected | 0 complete | 2 incomplete'
    assert_includes @console, 'Findings: 0 | 0 possible secret values | 0 sensitivity indicators'
    assert_includes @console, 'Errors: 2'
    assert_equal 2, @console.lines.grep(/: error:/).length
    assert_source_errors(missing, invalid)
  end

  def test_multiple_findings_and_source_errors_survive_report_failure
    first, last = finding_inputs
    missing, invalid = error_inputs
    report = File.join(@directory, 'absent', 'report.xml')
    console('--junit', report, missing, last, invalid, first)
    assert_equal 2, @code
    assert_console('[ERROR] Sensitive data scan', 'Execution: incomplete',
                   'Files: 4 selected | 2 complete | 2 incomplete', 'Errors: 3')
    assert_findings(first, last)
    assert_source_errors(missing, invalid)
    assert_report_failure(report)
  end

  def assert_report_failure(report)
    assert_equal 1, @console.scan('(report_write_failed)').length
    refute_includes @console, 'JUnit written:'
    refute_path_exists report
  end

  def test_json_and_junit_keep_multiple_findings_and_source_errors
    first, last = finding_inputs
    missing, invalid = error_inputs
    report = File.join(@directory, 'report.xml')
    scan('--puppet', '--junit', report, missing, last, invalid, first)
    assert_json_diagnostics(first, last, missing, invalid)
    assert_junit_diagnostics(report)
  end

  def assert_json_diagnostics(first, last, missing, invalid)
    assert_equal 2, @status.exitstatus
    refute @report['complete']
    assert @report['report_written']
    expected = [[missing, [], ['unreadable_path']], [last, [1], []],
                [invalid, [], ['puppet_inspection_failed']], [first, [1, 3], []]]
    actual = @report.fetch('files').map do |file|
      [file['file'], file['findings'].map { |finding| finding['line'] }, file['errors']]
    end
    assert_equal expected, actual
  end

  def assert_junit_diagnostics(report)
    xml = File.read(report)
    %w[tests="4" failures="2" errors="2"].each { |count| assert_includes xml, count }
    assert_equal 3, xml.scan('puppet_hardcoded_value').length
    %w[unreadable_path puppet_inspection_failed].each { |code| assert_equal 1, xml.scan(code).length }
    %w[synthetic-first-password synthetic-second-password synthetic-last-password].each do |value|
      assert_no_disclosure(value)
      refute_includes xml, value
    end
  end
end
