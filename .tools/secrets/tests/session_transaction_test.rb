# frozen_string_literal: true

require_relative 'session_helper'

# Fault injection exercises persisted intent and native replacement, without creating Git commits.
class SecretsSessionTransactionTest < SecretsSessionTestCase
  def test_staging_is_private_hidden_and_removed_after_success
    write('a.txt', 'before')
    prepare(['a.txt'])
    writer = transaction
    staged = observe_staging(writer)
    result = writer.apply({ 'a.txt' => 'after' }, [])
    assert_equal 'applied', result['status']
    assert_staging(staged)
    assert_equal ['a.txt'], Dir.children(@input)
  end

  def observe_staging(writer)
    staged = []
    writer.define_singleton_method(:replace) do |entry|
      directory = entry.fetch('staging')
      staged << [directory, File.stat(directory).mode & 0o777]
      super(entry)
    end
    staged
  end

  def assert_staging(staged)
    assert_equal 1, staged.size
    directory, mode = staged.first
    assert_equal @input, File.dirname(directory)
    assert_match(/\A\._secrets-[0-9a-f]{32}\z/, File.basename(directory))
    assert_equal 0o700, mode
    refute_path_exists directory
  end

  def test_second_file_failure_rolls_back_the_first_file
    first = write('a.txt', 'before a')
    second = write('b.txt', 'before b')
    prepare(%w[a.txt b.txt])
    writer = transaction
    writer.define_singleton_method(:replace) do |entry|
      raise IOError if entry['file'] == 'b.txt'

      super(entry)
    end
    result = writer.apply({ 'a.txt' => 'after a', 'b.txt' => 'after b' }, [])
    assert_rollback(result, first, second)
  end

  def assert_rollback(result, first, second)
    assert_equal 'rolled_back', result['status']
    assert_equal ['write_failed'], result['errors']
    assert_equal 'before a', File.read(first)
    assert_equal 'before b', File.read(second)
    assert_equal %w[a.txt b.txt], Dir.children(@input).sort
  end

  def test_abrupt_process_exit_can_be_recovered_from_the_persisted_journal
    path = write('a.txt', 'before')
    prepare(['a.txt'])
    interrupt_process
    assert_equal 1, Dir.glob(File.join(@input, '._secrets-*')).size
    call_session('recover', '--session', @session)
    assert_equal 'rolled_back', @result['status']
    assert_equal 'before', File.read(path)
    assert_equal ['a.txt'], Dir.children(@input)
  end

  def interrupt_process
    pid = fork do
      writer = transaction
      writer.define_singleton_method(:replace) do |entry|
        super(entry)
        Process.exit!(17)
      end
      writer.apply({ 'a.txt' => 'after' }, [])
    end
    Process.wait(pid)
  end
end
