# frozen_string_literal: true

require_relative 'session_helper'

# Fault injection exercises persisted intent and native replacement, without creating Git commits.
class SecretsSessionTransactionTest < SecretsSessionTestCase
  def transaction
    store = ProjectTools::Secrets::Store.new(@state)
    ProjectTools::Secrets::Transaction.new(store, @session, store.load(@session))
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
    assert_empty Dir.glob(File.join(@input, '.secrets-*'))
  end

  def test_abrupt_process_exit_can_be_recovered_from_the_persisted_journal
    path = write('a.txt', 'before')
    prepare(['a.txt'])
    interrupt_process
    call_session('recover', '--session', @session)
    assert_equal 'rolled_back', @result['status']
    assert_equal 'before', File.read(path)
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
