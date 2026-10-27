# frozen_string_literal: true

require_relative '../test_helper'

# Lookup metadata stays safe; every documented source of local default data is inspected.
class PuppetDefaultsTest < SecretsTest
  def test_lookup_hash_defaults_and_overrides_are_values
    source = <<~PUPPET
      $data = Sensitive(lookup('example', {default_values_hash => {'example' => 'synthetic-default'}}))
      $other = Sensitive(lookup('example', {'override' => {'example' => 'synthetic-override'}}))
    PUPPET
    assert_puppet_redaction(source, %w[default override])
  end

  def test_unquoted_keys_and_bare_string_values_are_inspected
    source = <<~PUPPET
      $settings = { password => 'synthetic-bare-key' }
      $password = synthetic_bare_value
    PUPPET
    assert_puppet_redaction(source, ['bare-key'])
    assert_masked('synthetic_bare_value')
  end

  def test_requested_resource_lookup_is_safe
    path = write('sample.pp', <<~PUPPET)
      mysql::user { 'example':
        ensure   => present,
        username => 'example',
        password => lookup('mysql::user::example::password', Sensitive[String]),
      }
    PUPPET
    scan('--puppet', path)
    assert_puppet_clean
  end

  def test_selector_labels_and_resource_state_are_not_credentials
    path = write('sample.pp', <<~PUPPET)
      $token_ensure = present
      $password = $ensure ? { present => $data.unwrap, default => undef }
    PUPPET
    scan('--puppet', path)
    assert_puppet_clean
  end
end
