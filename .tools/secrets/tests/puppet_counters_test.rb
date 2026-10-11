# frozen_string_literal: true

require_relative 'test_helper'

# Numeric counting must not hide other data in a sensitive expression.
class PuppetCountersTest < SecretsTest
  def test_counter_literals_are_not_credentials
    source = fixture('counts.pp')
    path = write('counts.pp', source)
    scan('--puppet', '--redact', @copies, path)
    assert_puppet_clean
    assert @report['complete']
    assert_empty @report['files'].first['errors']
    assert_equal source, copy
    assert_equal source, File.read(path)
    assert_unreviewed
  end

  def test_numeric_credentials_lookup_defaults_and_map_values_still_fail
    source = <<~PUPPET
      $password = 12345
      $other_password = lookup('example::password', String, 'first', 'synthetic-default')
      $api_key_name_counts = $api_keys.map |$item| { 'synthetic-credential' }
    PUPPET
    assert_puppet_redaction(source, %w[default credential])
    assert_masked('12345')
    assert_equal([1, 2, 3], @report['files'].first['findings'].map { |finding| finding['line'] })
  end

  def test_other_fields_in_the_counter_remain_sensitive
    source = fixture('counts.pp').sub('$api_key_name => 1', "$api_key_name => 1, 'other' => 'synthetic-nested'")
    assert_puppet_redaction(source, ['nested'])
  end

  def test_identical_numeric_literals_outside_the_count_are_still_values
    source = fixture('counts.pp').sub('$api_key_name => 1', "$api_key_name => 1, 'other' => 1")
    path = write('same-number.pp', "#{source}$password = 1\n")
    scan('--puppet', path)
    assert_equal 1, @status.exitstatus
    assert @report['complete']
    assert_equal([4, 10], @report['files'].first['findings'].map { |finding| finding['line'] })
  end

  def test_a_count_name_and_arbitrary_reduce_are_not_exemptions
    source = <<~PUPPET
      $api_key_name_counts = 12345
      $api_key_counts = $items.reduce({}) |$result, $item| { $result + { $item => 12345 } }
      $api_key_counts_other = $items.filter |$item| { 'synthetic-filter' }
    PUPPET
    assert_puppet_redaction(source, ['filter'])
    assert_masked('12345')
  end

  def test_mismatched_accumulator_keys_do_not_prove_a_counter
    source = fixture('counts.pp').sub('$result[$api_key_name] + 1', '$result[$other_name] + 1')
    path = write('mismatch.pp', source)
    scan('--puppet', path)
    assert_equal 1, @status.exitstatus
    assert @report['complete']
    assert_equal([4, 6], @report['files'].first['findings'].map { |finding| finding['line'] })
  end
end
