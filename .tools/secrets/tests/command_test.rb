# frozen_string_literal: true

require_relative 'session_helper'

# One executable publishes only prepared trees, including source containing marker examples.
class SecretsCommandTest < SecretsSessionTestCase
  def test_removed_copy_option_fails_without_output_files
    path = write('ordinary.txt', 'ordinary')
    scan('--redact', @copies, path)
    assert_equal 2, @status.exitstatus
    refute @report['complete']
    refute_path_exists @copies
    scan(path)
    assert_equal 0, @status.exitstatus
    refute @report.fetch('files').first.key?('copy')
  end

  def test_preparation_keeps_private_permissions_and_masks_confidential_names
    name = "ghp_#{'q' * 36}.txt"
    write(name, 'ordinary')
    prepare([name])
    safe = @result.fetch('files').first.fetch('file')
    refute_includes safe, name
    assert_equal 0o700, File.stat(@copies).mode & 0o777
    assert_equal 0o600, File.stat(File.join(@copies, safe)).mode & 0o777
  end

  def test_marker_examples_in_documentation_round_trip_without_trusting_analysis_markers
    original = "Example: [REDACTED-#{'a' * 32}]\nordinary: before\n"
    file = write('example.md', original)
    prepare(['example.md'])
    edit('example.md', analysis('example.md').sub('before', 'after'))
    apply('write' => ['example.md'])
    assert_applied
    assert_equal original.sub('before', 'after'), File.read(file)
    call_session('diff', '--session', @session)
    assert_reviewed
  end

  def test_marker_prefix_in_ruby_source_uses_the_same_preparation_and_writer
    original = "PREFIX = '[REDACTED-'\nLABEL = 'before'\n"
    file = write('example.rb', original)
    prepare(['example.rb'])
    edit('example.rb', analysis('example.rb').sub('before', 'after'))
    apply('write' => ['example.rb'])
    assert_applied
    assert_equal original.sub('before', 'after'), File.read(file)
  end
end
