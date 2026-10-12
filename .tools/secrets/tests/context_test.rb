# frozen_string_literal: true

require_relative 'test_helper'

# Each non-secret role has a nearby positive control with a literal credential.
class SecretsContextTest < SecretsTest
  def test_puppet_counter_and_file_server_reference
    path = write('sample.pp', <<~PUPPET)
      $api_key_count = 3
      $private_key = 'puppet:///modules/example/private.key'
      $backup_git = 'ssh://git@example.test/repository.git'
    PUPPET
    scan('--puppet', path)
    assert_puppet_clean
  end

  def test_policy_numbers_and_token_durations
    source = "password.minlength = 14\npassword.retrylimit = 5\npassword.expiration = 90\nTOKEN_EXPIRE=14d\n"
    path = write('sample.properties', source)
    scan(path)
    assert_complete_scan
    assert_equal source, sanitized
    refute(@report['files'].first['findings'].any? { |finding| finding['kind'] == 'value' })
  end

  def test_numeric_password_and_misused_metadata_fields_remain_values
    path = write('sample.env',
                 "PASSWORD=12345\nTOKEN_EXPIRE=synthetic-token-value\npassword.minlength=synthetic-password-value\n")
    scan(path)
    assert_complete_scan
    assert_masked('12345', 'synthetic-token-value', 'synthetic-password-value')
  end

  def test_erb_reference_is_preserved_but_a_fallback_is_masked
    source = "PASSWORD=<%= @password %>\nTOKEN=<%= ENV['TOKEN'] %>\n"
    path = write('sample.env', source)
    scan(path)
    assert_complete_scan
    assert_equal source, sanitized
    path = write('fallback.env', "PASSWORD=<%= @password || 'synthetic-fallback' %>\n")
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-fallback')
  end

  def test_ci_job_label_preserves_commands_but_rejects_literal_command_password
    source = "Puppet secrets:\n  stage: test\n  script:\n    - bundle exec rake secrets:puppet\n"
    path = write('pipeline.yaml', source)
    scan(path)
    assert_complete_scan
    assert_equal source, sanitized
  end

  def test_ci_job_with_literal_command_password
    path = write('unsafe.yaml',
                 "Puppet secrets:\n  stage: test\n  script:\n    - client --password=synthetic-command-value\n")
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-command-value')
  end

  def test_ssh_password_and_http_userinfo_are_still_credentials
    path = write('urls.txt', "ssh://git:synthetic-ssh-value@example.test/repository\nhttps://synthetic-http-value@example.test/\n")
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-ssh-value', 'synthetic-http-value')
  end

  def test_sensitive_computed_command_cannot_hide_literal_credentials
    source = <<~PUPPET
      $command = Sensitive("/bin/tool --password=synthetic-command-value ${runtime}")
      $other = Sensitive("/bin/tool --token synthetic-option-value ${runtime}")
    PUPPET
    assert_puppet_redaction(source, %w[command-value option-value])
  end

  def test_sensitive_computed_command_with_unclosed_argument_is_masked
    source = '$command = Sensitive("tool --password=\'synthetic-unclosed ${host}")'
    assert_puppet_redaction(source, ['unclosed'])
  end

  def test_explicit_hiera_conversion_overrides_numeric_metadata_role
    options = write('options.yaml', "lookup_options:\n  TOKEN_EXPIRE:\n    convert_to: Sensitive\n")
    data = write('data.yaml', "TOKEN_EXPIRE: 86400\n")
    scan(options, data)
    assert_complete_scan
    assert_masked('86400', index: 1)
  end

  def test_shell_fixture_assignments_use_the_enclosing_quote
    source = "printf '%s\\n' \"password=synthetic-shell-value\"\n"
    path = write('fixture.sh', source)
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-shell-value')
    assert_equal source, File.read(path)
  end
end
