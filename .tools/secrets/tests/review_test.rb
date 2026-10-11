# frozen_string_literal: true

require_relative 'test_helper'

# Reviewed content is exact, expires, and is never copied into analysis output.
class SecretsReviewTest < SecretsTest
  def entry(path, control)
    scan(path)
    file = @report['files'].first
    { 'path' => File.basename(path), 'control' => control, 'owner' => 'Synthetic reviewer',
      'rationale' => 'Synthetic contract test reviewed locally', 'reviewed_on' => Date.today.iso8601,
      'expires_on' => (Date.today + 30).iso8601, 'sha256' => Digest::SHA256.file(path).hexdigest,
      'findings' => file['findings'], 'errors' => file['errors'] }
  end

  def reviewed_scan(path, record)
    policy = File.join(@directory, 'policy.json')
    File.write(policy, JSON.generate({ schema: 1, entries: [record] }))
    Dir.chdir(@input) { scan('--review', policy, '--redact', @copies, path) }
  end

  def test_ambiguous_key_filename_requires_exact_review
    path = write('filename.pp', "$backup_private_key = 'example.key'\n")
    record = entry(path, 'non_secret_value')
    assert active_value?
    reviewed_scan(path, record)
    assert @report['complete']
    refute active_value?
    assert_reviewed_copy('non_secret_value')
  end

  def active_value?
    @report['files'].first['findings'].any? { |finding| finding['kind'] == 'value' }
  end

  def assert_reviewed_copy(control)
    assert_equal "reviewed_#{control}", @report['files'].first['coverage']
    assert_equal '[REVIEWED CONTENT WITHHELD]', copy
  end

  def test_binary_is_reviewed_explicitly_and_never_released_as_text
    path = write('artifact.bin', "\xFF\x00synthetic-payload".b)
    record = entry(path, 'non_secret_artifact')
    assert_equal 2, @status.exitstatus
    reviewed_scan(path, record)
    assert_equal 0, @status.exitstatus
    assert_reviewed_copy('non_secret_artifact')
    assert_equal ['unsupported_encoding'], @report['files'].first['reviewed_errors']
    assert_no_disclosure('synthetic-payload')
  end

  def test_changed_content_and_additional_findings_invalidate_review
    path = write('sample.env', 'password=synthetic-reviewed-fixture')
    record = entry(path, 'non_secret_value')
    File.write(path, 'password=synthetic-new-fixture')
    reviewed_scan(path, record)
    assert_equal 2, @status.exitstatus
    refute_path_exists @copies
    record['sha256'] = Digest::SHA256.file(path).hexdigest
    record['findings'] = []
    reviewed_scan(path, record)
    assert_withheld
  end

  def test_expired_broad_unknown_and_tool_failure_reviews_are_invalid
    path = write('sample.env', 'password=synthetic-reviewed-fixture')
    record = entry(path, 'non_secret_value')
    variants = [record.merge('expires_on' => Date.today.iso8601), record.merge('path' => '*.env'),
                record.merge('control' => 'ignore_everything'), record.merge('errors' => ['inspection_failed']),
                record.merge('unexpected' => true)]
    assert_invalid_reviews(path, variants)
  end

  def assert_invalid_reviews(path, variants)
    variants.each do |variant|
      reviewed_scan(path, variant)
      assert_withheld
      assert_includes @report['errors'], 'invalid_review_policy'
    end
  end

  def assert_withheld
    assert_equal 2, @status.exitstatus
    refute_path_exists @copies
  end

  def test_duplicate_policy_keys_and_missing_inputs_fail_closed
    policy = File.join(@directory, 'policy.json')
    File.write(policy, '{"schema":1,"schema":1,"entries":[]}')
    scan('--review', policy, @input)
    assert_equal 2, @status.exitstatus
    File.write(policy, JSON.generate({ schema: 1, entries: [] }))
    scan('--review', policy, '--redact', @copies, File.join(@input, 'missing'))
    assert_equal 2, @status.exitstatus
    refute_path_exists @copies
  end

  def test_junit_and_console_distinguish_reviewed_binary_from_inspected_text
    path = write('artifact.bin', "\xFF\x00synthetic-payload".b)
    record = entry(path, 'non_secret_artifact')
    reviewed_scan(path, record)
    assert_review_reporting(path)
  end

  def assert_review_reporting(path)
    report = File.join(@directory, 'report.xml')
    policy = File.join(@directory, 'policy.json')
    output = StringIO.new
    Dir.chdir(@input) do
      assert_equal 0, ProjectTools::Secrets.run(['--review', policy, '--junit', report, path], output: output)
    end
    assert_includes output.string, 'coverage=reviewed_non_secret_artifact'
    assert_includes File.read(report), 'reviewed_non_secret_artifact'
    refute_includes File.read(report), 'synthetic-payload'
  end
end
