# frozen_string_literal: true

require_relative 'external_helper'

# Public subcommands work without a Git repository, agent launcher or Puppet installation.
class ExternalSecretsSessionTest < ExternalSecretsTestCase
  def test_package_installs_exactly_one_executable
    run_success('bundle', 'exec', 'ruby', '-rproject_tools/secrets', '-e',
                "abort unless Gem.loaded_specs.fetch('project-tools-secrets').executables == ['project-tools-secrets']")
  end

  def test_installed_writer_round_trip_and_safe_diff
    prepare_session
    path = File.join(@project, 'analysis', 'data.yaml')
    File.write(path, File.read(path).sub('before', 'after'))
    write('changes.json', JSON.generate('write' => ['data.yaml']))
    run_success('bundle', 'exec', 'project-tools-secrets', 'write', *session_arguments, '--changes', 'changes.json')
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
    run_success('bundle', 'exec', 'project-tools-secrets', 'close', *session_arguments)
    assert_equal 'closed', JSON.parse(@output)['status']
  end

  def prepare_session(**policy)
    @synthetic = "synthetic-#{SecureRandom.hex(16)}"
    write('source/data.yaml', "password: '#{@synthetic}'\nordinary: before\n")
    write('policy.json', JSON.generate({ 'files' => ['data.yaml'] }.merge(policy.transform_keys(&:to_s))))
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

  def test_installed_support_operations_use_the_single_executable
    prepare_session(destinations: { 'extra.yaml' => '0600' }, fixture_paths: ['extra.yaml'],
                    commands: { 'check' => [Gem.ruby, '-e', 'exit 7'] })
    assert_installed_registration
    assert_installed_diagnostics
    run_success('bundle', 'exec', 'project-tools-secrets', 'cancel', *session_arguments)
    assert_equal 'cancelled', JSON.parse(@output)['status']
  end

  def assert_installed_registration
    write('private-value.txt', 'synthetic-local-registration')
    run_success('bundle', 'exec', 'project-tools-secrets', 'register', *session_arguments,
                '--input', 'private-value.txt', '--to', 'extra.yaml')
    refute_includes @output + @errors, 'synthetic-local-registration'
    assert_installed_fixture
  end

  def assert_installed_fixture
    run_success('bundle', 'exec', 'project-tools-secrets', 'fixture', *session_arguments, '--to', 'extra.yaml')
    marker = JSON.parse(@output).fetch('marker')
    run_success('bundle', 'exec', 'project-tools-secrets', 'clone', *session_arguments,
                '--id', marker[/[0-9a-f]{32}/], '--to', 'extra.yaml')
    refute_equal marker, JSON.parse(@output).fetch('marker')
  end

  def assert_installed_diagnostics
    command('bundle', 'exec', 'project-tools-secrets', 'run', *session_arguments, '--command', 'check')
    assert_equal 7, @status.exitstatus
    assert_equal 'executed', JSON.parse(@output)['status']
    command('bundle', 'exec', 'project-tools-secrets', 'recover', *session_arguments)
    assert_equal 2, @status.exitstatus
    assert_equal ['recovery_not_required'], JSON.parse(@output)['errors']
  end
end
