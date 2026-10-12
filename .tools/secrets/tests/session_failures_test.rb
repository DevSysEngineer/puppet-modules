# frozen_string_literal: true

require_relative 'session_helper'

# No source content escapes validation, failure, rollback or report channels.
class SecretsSessionFailuresTest < SecretsSessionTestCase
  def test_incomplete_selection_never_releases_partial_copies
    write('good.txt', 'ordinary')
    File.write(@policy, JSON.generate('files' => ['good.txt', 'missing.txt']))
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy)
    refute @result['complete']
    refute_path_exists @copies
  end

  def test_consumed_missing_and_incompatible_sessions_are_refused
    write('a.txt', 'ordinary')
    prepare(['a.txt'])
    apply('write' => ['a.txt'])
    apply('write' => ['a.txt'])
    assert_equal ['session_consumed'], @result['errors']
    call_session('close', '--session', @session)
    apply('write' => ['a.txt'])
    assert_equal ['session_unavailable'], @result['errors']
  end

  def test_invalid_yaml_and_shell_are_rejected_before_any_file_is_written
    original = write('a.txt', 'before')
    write('b.sh', "#!/bin/sh\nprintf '%s' ordinary\n")
    prepare(%w[a.txt b.sh])
    edit('a.txt', 'after')
    edit('b.sh', 'if then')
    apply('write' => %w[a.txt b.sh])
    assert_equal ['invalid_shell'], @result['errors']
    assert_equal 'before', File.read(original)
  end

  def test_captured_stdout_and_stderr_mask_local_values
    write('a.yaml', "password: '#{@value}'\n")
    command = [Gem.ruby, '-e', "print File.read('a.yaml'); warn File.read('a.yaml')"]
    prepare(['a.yaml'], commands: { 'diagnose' => command })
    call_session('run', '--session', @session, '--command', 'diagnose')
    assert_equal 'executed', @result['status']
    assert_includes @result['stdout'], '[REDACTED]'
    assert_includes @result['stderr'], '[REDACTED]'
  end

  def test_report_failure_retains_applied_status
    file = write('a.txt', 'before')
    prepare(['a.txt'])
    edit('a.txt', 'after')
    change = File.join(@directory, 'change.json')
    File.write(change, JSON.generate('write' => ['a.txt']))
    call_session('apply', '--session', @session, '--changes', change, '--junit', @policy)
    assert_applied
    assert_equal 'report_write_failed', @result['report_error']
    assert_equal 2, @code
    assert_equal 'after', File.read(file)
  end

  def test_recovery_preserves_an_external_change_after_process_interruption
    file = write('a.txt', 'before')
    prepare(['a.txt'])
    interrupted_transaction
    File.write(file, 'someone else')
    call_session('recover', '--session', @session)
    assert_equal 'recovery_required', @result['status']
    assert_equal 'external_change', @result['files'].first['state']
    assert_equal 'someone else', File.read(file)
  end

  def test_recovery_can_restore_the_version_written_by_this_transaction
    file = write('a.txt', 'before')
    prepare(['a.txt'])
    transaction, data = interrupted_transaction
    transaction.stage(data['journal'].first)
    transaction.replace(data['journal'].first)
    call_session('recover', '--session', @session)
    assert_equal 'rolled_back', @result['status']
    assert_equal 'before', File.read(file)
  end

  def interrupted_transaction
    store = ProjectTools::Secrets::Store.new(@state)
    data = store.load(@session)
    transaction = ProjectTools::Secrets::Transaction.new(store, @session, data)
    data['status'] = 'writing'
    data['journal'] = [transaction.operation('a.txt', 'ours').merge('state' => 'replacing')]
    store.save(@session, data)
    [transaction, data]
  end
end
