# frozen_string_literal: true

require_relative 'session_helper'

# Complete document rewrites and policy checks.
class SecretsSessionTest < SecretsSessionTestCase
  def test_full_yaml_rewrite_preserves_original_literal_and_changes_ordinary_content
    original = "password: '#{@value}'\nordinary: before\n"
    file = write('data/common.yaml', original)
    prepare(['data/common.yaml'])
    assert_equal 1, @code
    marker_line = analysis('data/common.yaml').lines.first
    edit('data/common.yaml', "ordinary: after\n#{marker_line}")
    apply('write' => ['data/common.yaml'])
    assert_applied
    assert_equal "ordinary: after\npassword: '#{@value}'\n", File.read(file)
    assert_diff_change
  end

  def assert_diff_change
    call_session('diff', '--session', @session)
    assert_reviewed
    assert_includes @result['diff'], 'after'
  end

  def test_noop_preserves_bytes_and_inode
    file = write('sample.txt', "ordinary=before\r\n")
    inode = File.stat(file).ino
    prepare(['sample.txt'])
    apply('write' => ['sample.txt'])
    assert_applied
    assert_equal inode, File.stat(file).ino
    assert_equal "ordinary=before\r\n", File.binread(file)
  end

  def test_conflict_and_unknown_markers_leave_sources_untouched
    file = write('a.yaml', "password: '#{@value}'\n")
    prepare(['a.yaml'])
    edit('a.yaml', analysis('a.yaml').sub(/REDACTED-[a-f0-9]+/, "REDACTED-#{'0' * 32}"))
    apply('write' => ['a.yaml'])
    assert_equal ['unknown_marker'], @result['errors']
    File.write(file, 'changed by user')
    apply('write' => ['a.yaml'])
    assert_equal ['source_conflict'], @result['errors']
    assert_equal 'changed by user', File.read(file)
  end

  def test_duplicate_in_new_file_counts_unchanged_original
    write('a.yaml', "password: '#{@value}'\n")
    prepare(['a.yaml'], destinations: { 'b.yaml' => '0600' })
    edit('b.yaml', analysis('a.yaml'))
    apply('add' => ['b.yaml'])
    assert_equal ['duplicate_marker'], @result['errors']
    refute_path_exists File.join(@input, 'b.yaml')
  end

  def test_puppet_gate_checks_restored_source_and_allows_explicit_hiera_migration
    file = write('modules/example/manifests/init.pp', "$password = '#{@value}'\n")
    prepare(['modules/example/manifests/init.pp'], destinations: { 'data/common.yaml' => '0600' })
    apply('write' => ['modules/example/manifests/init.pp'])
    assert_equal ['puppet_policy_rejected'], @result['errors']
    marker = analysis('modules/example/manifests/init.pp')[ProjectTools::Secrets::Document::MARKER]
    edit('modules/example/manifests/init.pp', "$password = lookup('example::password')\n")
    edit('data/common.yaml', "example::password: '#{marker}'\n")
    apply('write' => ['modules/example/manifests/init.pp'], 'add' => ['data/common.yaml'],
          'move_ids' => { marker[ProjectTools::Secrets::Document::MARKER, 1] => 'data/common.yaml' })
    assert_hiera_migration(file)
  end

  def assert_hiera_migration(file)
    assert_applied
    assert_includes File.read(file), 'lookup'
    assert_equal @value, Psych.safe_load_file(File.join(@input, 'data/common.yaml'))['example::password']
  end
end
