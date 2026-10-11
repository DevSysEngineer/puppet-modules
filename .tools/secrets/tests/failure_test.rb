# frozen_string_literal: true

require_relative 'test_helper'

# Fail-closed behavior includes filesystem failures and parser exhaustion.
class SecretsFailureTest < SecretsTest
  def test_unreadable_files_are_incomplete
    path = write('private.txt', 'password=synthetic-unreadable')
    File.chmod(0o000, path)
    scan('--redact', @copies, path)
    assert_equal 2, @status.exitstatus
    refute @report['files'][0]['complete']
    assert_no_disclosure('synthetic-unreadable')
    refute_path_exists @copies
  ensure
    File.chmod(0o600, path) if path
  end

  def test_unreadable_directories_do_not_count_as_scanned
    File.chmod(0o000, @input)
    scan('--redact', @copies, @input)
    assert_equal 2, @status.exitstatus
    refute @report['files'][0]['complete']
    refute_path_exists @copies
  ensure
    File.chmod(0o700, @input)
  end

  def test_deep_yaml_does_not_leak_a_stack_trace_or_release_copies
    path = write('deep.yaml', "#{'[' * 12_000}synthetic-deep#{']' * 12_000}")
    scan('--redact', @copies, path)
    assert_equal 2, @status.exitstatus
    refute @report['complete']
    refute @report['files'][0]['complete']
    assert_empty @err
    assert_no_disclosure('synthetic-deep')
    refute_path_exists @copies
  end

  def test_failed_copy_removes_previously_written_sanitized_files
    first = ProjectTools::Secrets::Document.new('one', 'ordinary')
    second = ProjectTools::Secrets::Document.new('two')
    second.error('inspection_failed')
    writer = ProjectTools::Secrets::Output.new([first, second], [])
    assert_raises(ArgumentError) { writer.redact(@copies) }
    refute_path_exists @copies
    assert_nil first.copy
  end

  def test_clean_and_incomplete_junit_cases_have_distinct_statuses
    path = write('clean.txt', 'ordinary')
    report = File.join(@directory, 'clean.xml')
    scan('--junit', report, path)
    assert_equal 0, @status.exitstatus
    assert_includes File.read(report), 'failures="0" errors="0"'
    scan('--junit', File.join(@directory, 'bad.xml'), File.join(@input, 'missing'))
    assert_equal 2, @status.exitstatus
    assert_includes File.read(File.join(@directory, 'bad.xml')), 'errors="1"'
  end

  def test_interrupted_scan_never_claims_selected_files_were_fully_checked
    scanner = Class.new(ProjectTools::Secrets::Scanner) do
      def scan_yaml
        raise Interrupt
      end
    end.new
    path = write('settings.txt', 'password=synthetic-interrupted')
    assert_raises(Interrupt) { scanner.scan([path]) }
    refute scanner.documents.first.complete?
  end
end
