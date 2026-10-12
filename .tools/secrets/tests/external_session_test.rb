# frozen_string_literal: true

require_relative 'external_helper'

# Both public executables work without a Git repository, agent launcher or Puppet installation.
class ExternalSecretsSessionTest < ExternalSecretsTestCase
  def test_installed_writer_round_trip_and_safe_diff
    prepare_session
    path = File.join(@project, 'analysis', 'data.yaml')
    File.write(path, File.read(path).sub('before', 'after'))
    write('changes.json', JSON.generate('write' => ['data.yaml']))
    run_success('bundle', 'exec', 'project-tools-secrets-write', *session_arguments, '--changes', 'changes.json')
    assert_equal 'applied', JSON.parse(@output)['status']
    assert_restored_source
    refute_path_exists File.join(@project, '.git')
    assert_safe_diff
  end

  def assert_restored_source
    restored = read('source/data.yaml')
    assert_includes restored, 'after'
    assert_includes restored, @synthetic
  end

  def assert_safe_diff
    run_success('bundle', 'exec', 'project-tools-secrets', 'diff', *session_arguments)
    assert_includes JSON.parse(@output)['diff'], '[REDACTED-'
    refute_includes @output + @errors, @synthetic
  end

  def prepare_session
    @synthetic = "synthetic-#{SecureRandom.hex(16)}"
    write('source/data.yaml', "password: '#{@synthetic}'\nordinary: before\n")
    write('policy.json', JSON.generate('files' => ['data.yaml']))
    command('bundle', 'exec', 'project-tools-secrets', 'prepare', '--root', 'source',
            '--tree', 'analysis', '--policy', 'policy.json', '--state', 'state')
    assert_equal 1, @status.exitstatus, @output + @errors
    result = JSON.parse(@output)
    assert result['prepared']
    @session = result.fetch('session')
  end

  def session_arguments
    ['--state', 'state', '--session', @session]
  end
end
