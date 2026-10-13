# frozen_string_literal: true

require_relative 'test_helper'

# Review the user-visible diagnosis as well as the scan status and disclosure boundary.
class SecretsConsoleOutputTest < SecretsTest
  def console(*arguments)
    output = StringIO.new
    @code = ProjectTools::Secrets.run(arguments, output: output)
    @console = output.string
  end

  def assert_console(*messages)
    messages.each { |message| assert_includes @console, message }
  end

  def test_one_finding_stands_out_among_many_clean_files
    56.times { |index| write("clean-#{index}.pp", "notify { 'ordinary': }\n") }
    path = write('problem.pp', "$password = 'synthetic-console-value'\n")
    console('--puppet', @input)
    assert_equal 1, @code
    assert_console('[FAILED] Sensitive data scan', 'Files: 57 selected | 57 complete | 0 incomplete',
                   'Findings: 1 | 1 possible secret values | 0 sensitivity indicators')
    assert_console("#{path} | line=1 | possible secret value:", '(puppet_hardcoded_value)',
                   'A sensitive Puppet setting or Sensitive wrapper contains a hardcoded value.')
    %w[clean- no_findings synthetic-console-value].each { |text| refute_includes @console, text }
  end

  def test_clean_scan_only_prints_totals
    path = write('ordinary.txt', 'ordinary')
    console(@input)
    assert_equal 0, @code
    assert_console('[PASSED] Sensitive data scan', 'Files: 1 selected | 1 complete | 0 incomplete',
                   'Findings: 0 | 0 possible secret values | 0 sensitivity indicators', 'Errors: 0', 'Coverage: 1 text')
    refute_includes @console, path
  end

  def test_indicators_have_explanations_without_claiming_a_secret_value
    path = write('reference.txt', "password = $reference\n")
    console(path)
    assert_equal 1, @code
    assert_includes @console, '0 possible secret values | 2 sensitivity indicators'
    assert_includes @console, 'sensitivity indicator: A name indicates potentially sensitive data. (sensitive_name)'
    assert_includes @console, 'sensitivity indicator: An assignment targets a sensitive field. (sensitive_assignment)'
  end

  def test_incomplete_scan_keeps_findings_and_explains_the_error
    problem = write('problem.pp', "$password = 'synthetic-incomplete-value'\n")
    missing = File.join(@input, 'missing.pp')
    console('--puppet', problem, missing)
    assert_equal 2, @code
    assert_console('[ERROR] Sensitive data scan', 'Execution: incomplete',
                   'Files: 2 selected | 1 complete | 1 incomplete')
    assert_console('(puppet_hardcoded_value)', '(unreadable_path)',
                   "#{missing}: error: The path could not be read;")
    refute_includes @console, 'synthetic-incomplete-value'
  end

  def test_report_failure_preserves_findings_and_does_not_claim_a_written_report
    path = write('problem.pp', "$password = 'synthetic-report-value'\n")
    report = File.join(@directory, 'absent', 'report.xml')
    console('--puppet', '--junit', report, path)
    assert_equal 2, @code
    assert_console('The requested JUnit report could not be written; scan findings remain valid.',
                   '(report_write_failed)', '(puppet_hardcoded_value)', 'Errors: 1')
    refute_includes @console, 'JUnit written:'
    refute_includes @console, 'synthetic-report-value'
  end

  def test_invalid_arguments_do_not_claim_an_empty_successful_scan
    console('--unknown')
    assert_equal 2, @code
    assert_console('Files: selection not evaluated', 'Invalid arguments or output destination; check --help.')
    refute_includes @console, 'Files: 0'
  end

  def test_diagnostics_are_sorted_and_keep_every_finding
    last = write('z-last.txt', "password = $reference\n")
    first = write('a-first.txt', "password = $reference\npassword = $reference\n")
    console(last, first)
    assert_equal 1, @code
    diagnostics = @console.lines.grep(/sensitivity indicator:/)
    assert_equal 6, diagnostics.length
    assert_includes diagnostics.first, "#{first} | line=1 |"
    assert_includes diagnostics[2], "#{first} | line=2 |"
    assert_includes diagnostics.last, "#{last} | line=1 |"
  end

  def machine_inputs
    clean = write('ordinary.pp', "notify { 'ordinary': }\n")
    problem = write('problem.pp', "$password = 'synthetic-machine-value'\n")
    [clean, problem]
  end

  def test_junit_keeps_clean_files_and_the_same_finding
    clean, = machine_inputs
    report = File.join(@directory, 'report.xml')
    console('--puppet', '--junit', report, @input)
    assert_equal 1, @code
    xml = File.read(report)
    assert_includes xml, clean
    assert_includes xml, 'failures="1"'
    assert_includes xml, 'puppet_hardcoded_value'
    refute_includes xml, 'synthetic-machine-value'
  end

  def test_json_keeps_clean_files_and_the_same_finding
    clean, problem = machine_inputs
    scan('--puppet', @input)
    assert_complete_scan
    files = @report.fetch('files')
    assert_equal [clean, problem], files.map { |file| file['file'] }.to_a
    assert_empty files.first['findings']
    assert_equal [{ 'line' => 1, 'rule' => 'puppet_hardcoded_value', 'kind' => 'value' }],
                 files.last['findings']
    assert_no_disclosure('synthetic-machine-value')
  end
end
