# frozen_string_literal: true

require_relative 'test_helper'

# Fail-closed behavior includes filesystem failures and parser exhaustion.
class SecretsFailureTest < SecretsTest
  def test_unreadable_files_are_incomplete
    path = write('private.txt', 'password=synthetic-unreadable')
    File.chmod(0o000, path)
    scan(path)
    assert_equal 2, @status.exitstatus
    refute @report['files'][0]['complete']
    assert_no_disclosure('synthetic-unreadable')
  ensure
    File.chmod(0o600, path) if path
  end

  def test_unreadable_directories_do_not_count_as_scanned
    File.chmod(0o000, @input)
    scan(@input)
    assert_equal 2, @status.exitstatus
    refute @report['files'][0]['complete']
  ensure
    File.chmod(0o700, @input)
  end

  def test_deep_yaml_fails_without_leaking_a_stack_trace
    path = write('deep.yaml', "#{'[' * 12_000}synthetic-deep#{']' * 12_000}")
    scan(path)
    assert_equal 2, @status.exitstatus
    refute @report['complete']
    refute @report['files'][0]['complete']
    assert_empty @err
    assert_no_disclosure('synthetic-deep')
  end

  def test_failed_publication_removes_partial_analysis_tree
    target = File.join(@directory, 'analysis')
    publication = ProjectTools::Secrets::Publication.new([])
    assert_raises(ProjectTools::Secrets::Failure) do
      publication.analysis_tree(target, { 'one' => 'ordinary', '../outside' => 'other' })
    end
    refute_path_exists target
    assert_empty Dir.glob(File.join(@directory, '.secrets-analysis-*'))
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
