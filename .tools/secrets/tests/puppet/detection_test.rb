# frozen_string_literal: true

require_relative '../test_helper'

# Static Puppet inspection must distinguish values from references without evaluation.
class PuppetSecretsTest < SecretsTest
  def test_values_in_parameters_resources_variables_hashes_and_sensitive_wrappers
    source = fixture('../puppet/fixtures/values.pp')
    assert_puppet_redaction(source, %w[default key token resource wrapped constructor encryption signing])
  end

  def test_safe_references_and_sensitive_types
    path = write('sample.pp', <<~PUPPET)
      class sample(Optional[Sensitive[String]] $password = undef) {
        $token = lookup('sample::token', Sensitive[String])
        $secret = Sensitive($password)
        sample::user { 'example': password => $config['password'].unwrap }
        $api_key = lookup({ 'name' => 'sample::key', 'value_type' => Sensitive[String] })
      }
    PUPPET
    scan('--puppet', path)
    assert_puppet_clean
  end

  def test_lookup_defaults_and_lambda_are_checked
    source = <<~PUPPET
      $password = lookup('sample::password', Sensitive[String], 'first', 'synthetic-default')
      $token = lookup({ 'name' => 'sample::token', 'default_value' => 'synthetic-option' })
      $api_key = lookup('sample::key') |$key| { 'synthetic-lambda' }
      $data = Sensitive(lookup('ordinary', String, 'first', 'synthetic-wrapped-default'))
      $mixed = Sensitive(['synthetic-mixed', $reference])
    PUPPET
    assert_puppet_redaction(source, %w[default option lambda wrapped-default mixed])
  end

  def test_sensitive_computed_commands_and_template_references
    path = write('sample.pp', <<~PUPPET)
      $command = Sensitive("/bin/tool ${password.unwrap}")
      $data = Sensitive.new(template('sample/config.erb'))
      $runner = Sensitive(join(['exec', $command], ' '))
      $password_file = '/run/example/password'
      $password_warn_days = 7
    PUPPET
    scan('--puppet', path)
    assert_equal 0, @status.exitstatus, @out + @err
  end

  def test_invalid_puppet_is_incomplete
    path = write('broken.pp', "$password = 'synthetic-unclosed")
    scan('--puppet', path)
    assert_equal 2, @status.exitstatus
    refute @report['complete']
    assert_no_disclosure('synthetic-unclosed')
  end

  def test_directory_batch_selects_manifests_and_rejects_an_empty_selection
    write('ordinary.txt', 'ordinary')
    scan('--puppet', @input)
    assert_equal 2, @status.exitstatus
    write('nested/sample.pp', "notify { 'synthetic': }")
    scan('--puppet', @input)
    assert_equal 0, @status.exitstatus
    assert_equal 1, @report['files'].length
  end

  def test_directory_symlinks_cannot_silently_reduce_the_puppet_scope
    write('sample.pp', "notify { 'synthetic': }")
    File.symlink(@directory, File.join(@input, 'linked-directory'))
    scan('--puppet', @input)
    assert_equal 2, @status.exitstatus
    refute @report['complete']
  end
end
