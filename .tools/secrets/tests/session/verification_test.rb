# frozen_string_literal: true

require_relative '../session_helper'

# Verify final sources before success and retain recovery material for external changes.
class SecretsSessionVerificationTest < SecretsSessionTestCase
  def setup
    super
    @first = write('a.txt', 'before a')
    @second = write('b.txt', 'before b')
    File.chmod(0o640, @first)
    prepare(%w[a.txt b.txt], destinations: { 'c.txt' => '0644' })
  end

  def test_writes_additions_and_deletions_pass_final_verification
    metadata = file_metadata(@first)
    result = transaction.apply({ 'a.txt' => '', 'b.txt' => nil, 'c.txt' => 'new' }, [])
    assert_equal 'applied', result['status']
    assert result['complete']
    assert_final_sources(metadata)
  end

  def assert_final_sources(metadata)
    assert_empty File.read(@first)
    assert_equal metadata, file_metadata(@first)
    refute_path_exists @second
    assert_equal 'new', File.read(File.join(@input, 'c.txt'))
    assert_equal %w[a.txt c.txt], Dir.children(@input).sort
  end

  def test_a_later_replacement_exposes_changes_to_an_earlier_file
    result = interfere_after_replacing('a.txt' => 'after a', 'b.txt' => 'after b') do
      File.write(@first, 'external')
    end
    assert_conflict(result)
    assert_equal 'external', File.read(@first)
    assert_equal 'before b', File.read(@second)
    assert_equal 'restored', result['files'].last['state']
  end

  def test_metadata_changes_are_preserved
    result = interfere_after_replacing { File.chmod(0o600, @first) }
    assert_conflict(result)
    assert_equal 'after a', File.read(@first)
    assert_equal 0o600, File.stat(@first).mode & 0o777
  end

  def test_an_identical_replacement_by_another_process_is_preserved
    replacement = File.join(@directory, 'replacement')
    result = interfere_after_replacing do
      FileUtils.cp(@first, replacement, preserve: true)
      File.rename(replacement, @first)
    end
    assert_conflict(result)
    assert_equal 'after a', File.read(@first)
    assert_equal 0o640, File.stat(@first).mode & 0o777
  end

  def test_a_recreated_deleted_file_is_preserved
    result = interfere_after_replacing('a.txt' => nil) { File.write(@first, 'external') }
    assert_conflict(result)
    assert_equal 'external', File.read(@first)
  end

  def test_a_missing_written_file_is_a_conflict
    result = interfere_after_replacing { File.unlink(@first) }
    assert_conflict(result)
    refute_path_exists @first
  end

  def test_a_symlink_after_deletion_is_rejected_without_following_it
    result = interfere_after_replacing('a.txt' => nil) { File.symlink(@second, @first) }
    assert_conflict(result, error: 'symlink_path', state: 'recovery_failed')
    assert File.symlink?(@first)
    assert_equal 'before b', File.read(@second)
  end

  def interfere_after_replacing(candidates = { 'a.txt' => 'after a' }, &interference)
    writer = transaction
    writer.define_singleton_method(:replace) do |entry|
      super(entry)
      interference.call if entry['file'] == candidates.keys.last
    end
    writer.apply(candidates, [])
  end

  def assert_conflict(result, error: 'source_conflict', state: 'external_change')
    assert_equal 'recovery_required', result['status']
    refute result['complete']
    assert_equal [error], result['errors']
    assert_equal state, result['files'].first['state']
    backups = Dir.glob(File.join(@input, '._secrets-*', 'before'))
    assert backups.any? { |path| File.read(path) == 'before a' }, 'Keep the original recovery copy'
  end
end
