# frozen_string_literal: true

require_relative 'session_helper'

# Explicit operations are checked against the whole intended final state.
class SecretsSessionOperationsTest < SecretsSessionTestCase
  def test_identical_values_get_different_ids_and_sensitive_paths_get_aliases
    write('data/person.yaml', "first_password: '#{@value}'\nsecond_password: '#{@value}'\n")
    prepare(['data/person.yaml'], aliases: { 'data/person.yaml' => 'data/record.yaml' })
    ids = analysis('data/record.yaml').scan(ProjectTools::Secrets::Document::MARKER).flatten
    assert_equal 2, ids.uniq.size
    refute_path_exists File.join(@copies, 'data/person.yaml')
  end

  def test_explicit_removal_deletes_only_the_selected_occurrence
    file = write('a.yaml', "password: '#{@value}'\nordinary: kept\n")
    prepare(['a.yaml'])
    id = marker_id('a.yaml')
    edit('a.yaml', "ordinary: kept\n")
    apply('write' => ['a.yaml'])
    assert_equal ['missing_marker'], @result['errors']
    apply('write' => ['a.yaml'], 'remove_ids' => [id])
    assert_applied
    assert_equal "ordinary: kept\n", File.read(file)
  end

  def test_clone_and_rename_preserve_values_and_file_mode
    old = write('a.yaml', "password: '#{@value}'\n")
    File.chmod(0o640, old)
    prepare(['a.yaml'], destinations: { 'nested/b.yaml' => '0600', 'c.yaml' => '0600' })
    call_session('clone', '--session', @session, '--id', marker_id('a.yaml'), '--to', 'c.yaml')
    edit('c.yaml', "password: '#{@result['marker']}'\n")
    edit('nested/b.yaml', analysis('a.yaml'))
    apply('rename' => { 'a.yaml' => 'nested/b.yaml' }, 'add' => ['c.yaml'])
    assert_applied
    assert_renamed(old)
  end

  def assert_renamed(old)
    refute_path_exists old
    assert_equal 0o640, File.stat(File.join(@input, 'nested/b.yaml')).mode & 0o777
    assert_equal @value, Psych.safe_load_file(File.join(@input, 'c.yaml'))['password']
  end

  def test_new_plain_value_and_marker_in_a_yaml_key_are_rejected
    file = write('a.yaml', "password: '#{@value}'\n")
    prepare(['a.yaml'])
    original = analysis('a.yaml')
    edit('a.yaml', "#{original}other_password: 'synthetic-unregistered'\n")
    apply('write' => ['a.yaml'])
    assert_equal ['unregistered_value'], @result['errors']
    edit('a.yaml', "'#{marker('a.yaml')}': ordinary\n")
    apply('write' => ['a.yaml'], 'move_ids' => { marker_id('a.yaml') => 'a.yaml' })
    assert_equal ['unsupported_marker_context'], @result['errors']
    assert_includes File.read(file), @value
  end

  def test_changed_hiera_context_and_new_destination_are_conflicts
    context = write('options.yaml', "lookup_options:\n  unknown:\n    convert_to: Sensitive\n")
    write('a.yaml', "unknown: '#{@value}'\n")
    prepare(['a.yaml'], context: ['options.yaml'], destinations: { 'b.yaml' => '0600' })
    refute_includes analysis('a.yaml'), @value
    File.write(context, "{}\n")
    apply('write' => ['a.yaml'])
    assert_equal ['source_conflict'], @result['errors']
  end

  def test_a_new_destination_is_not_overwritten_after_preparation
    write('a.txt', "ordinary\n")
    prepare(['a.txt'], destinations: { 'b.txt' => '0644' })
    file = write('b.txt', 'someone else')
    edit('b.txt', 'ours')
    apply('add' => ['b.txt'])
    assert_equal ['destination_conflict'], @result['errors']
    assert_equal 'someone else', File.read(file)
  end

  def test_shell_and_template_fragments_keep_quotes_and_executable_bit
    files = %w[setup.sh config.erb]
    files.each { |path| write(path, "PASSWORD='#{@value}'\nordinary=before\n") }
    File.chmod(0o755, File.join(@input, 'setup.sh'))
    prepare(files)
    files.each { |path| edit(path, analysis(path).sub('before', 'after')) }
    apply('write' => files)
    assert_applied
    assert_executable_sources(files)
  end

  def assert_executable_sources(files)
    assert_equal 0o755, File.stat(File.join(@input, 'setup.sh')).mode & 0o777
    files.each { |path| assert_includes File.read(File.join(@input, path)), @value }
  end

  def test_yaml_quote_and_indentation_changes_preserve_unicode_and_escapes
    @value = "synthetic-ü-\\-'-\nsecond"
    file = write('a.yaml', "password: #{JSON.generate(@value)}\n")
    prepare(['a.yaml'])
    id = marker_id('a.yaml')
    edit('a.yaml', "outer:\n  password: '#{marker('a.yaml')}'\n")
    apply('write' => ['a.yaml'], 'move_ids' => { id => 'a.yaml' })
    assert_applied
    assert_equal @value, Psych.safe_load_file(file)['outer']['password']
  end

  def test_traversal_and_symlinks_are_rejected
    write('a.txt', 'ordinary')
    prepare(['a.txt'])
    apply('add' => ['../outside.txt'])
    assert_equal ['unauthorized_destination'], @result['errors']
    File.unlink(File.join(@copies, 'a.txt'))
    File.symlink(File.join(@input, 'a.txt'), File.join(@copies, 'a.txt'))
    apply('write' => ['a.txt'])
    assert_equal ['symlink_path'], @result['errors']
  end
end
