# frozen_string_literal: true

require_relative 'test_helper'

# Boundary tests guard complete values rather than only obvious first lines.
class SecretsBoundariesTest < SecretsTest
  def test_yaml_unicode_and_quoted_null_are_values
    path = write('values.yaml', "ordinary: café\npassword: 'null'\ntoken: '$literal'\n")
    scan(path)
    assert_complete_scan
    assert_equal({ 'ordinary' => 'café', 'password' => '[REDACTED]', 'token' => '[REDACTED]' },
                 Psych.safe_load(sanitized))
  end

  def test_all_yaml_block_lines_are_removed_from_sanitized_content_and_reports
    path = write('values.yaml', fixture('blocks.txt'))
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-one', 'synthetic-two', 'synthetic-folded', 'synthetic-following',
                  'synthetic-nested', 'synthetic-list')
  end

  def test_sensitive_argument_in_markdown_does_not_consume_surrounding_prose
    path = write('guide.md', "Keep `Sensitive('synthetic-doc')` near the example.\n")
    scan(path)
    assert_complete_scan
    assert_equal "Keep `Sensitive('[REDACTED]')` near the example.\n", sanitized
  end

  def test_indexed_assignment_and_crlf_quoted_value
    path = write('settings.txt', "settings['password'] = \"synthetic-indexed\r\nsynthetic-continued\"\r\n")
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-indexed', 'synthetic-continued')
  end

  def test_multiple_assignments_and_escaped_quotes
    path = write('settings.txt', "password='synthetic-one'; api_key=\"synthetic-two\\\"suffix\"\n")
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-one', 'synthetic-two', 'suffix')
  end

  def test_unquoted_indented_continuation_is_withheld
    path = write('settings.ini', "password = synthetic-first\n  synthetic-second\nordinary = yes\n")
    scan(path)
    assert_equal 2, @status.exitstatus
    assert_no_disclosure('synthetic-first', 'synthetic-second')
  end

  def test_token_signature_consumes_trailing_hyphen
    value = "glpat-#{'a' * 22}-"
    path = write('opaque.txt', value)
    scan(path)
    assert_complete_scan
    assert_equal '[REDACTED]', sanitized
  end

  def test_yaml_explicit_strings_and_puppet_null_words_are_masked
    path = write('data.yaml', "password: !!str null\nsecret: undef\ntoken: nil\n")
    scan(path)
    assert_complete_scan
    assert_equal %w[password secret token].to_h { |key| [key, '[REDACTED]'] }, Psych.safe_load(sanitized)
  end

  def test_nested_private_key_blocks_are_withheld
    path = write('keys.pem', "-----BEGIN PRIVATE KEY-----\n-----BEGIN PRIVATE KEY-----\n" \
                             "synthetic-body\n-----END PRIVATE KEY-----\nremaining-body\n")
    scan(path)
    assert_equal 2, @status.exitstatus
    assert_no_disclosure('synthetic-body', 'remaining-body')
  end

  def test_quoted_indented_continuation_is_also_withheld
    path = write('settings.ini', "password = 'synthetic-first'\n  synthetic-second\nordinary = yes\n")
    scan(path)
    assert_equal 2, @status.exitstatus
    assert_no_disclosure('synthetic-first', 'synthetic-second')
  end

  def test_nested_encrypted_delimiters_do_not_release_the_remainder
    path = write('opaque.txt', 'ENC[PKCS7,synthetic-first[inner]synthetic-last]')
    scan(path)
    assert_equal 2, @status.exitstatus
    assert_no_disclosure('synthetic-first', 'synthetic-last')
  end

  def test_heredoc_inside_sensitive_is_withheld
    path = write('settings.pp', "$opaque = Sensitive(@(END))\nsynthetic-heredoc\nEND\n")
    scan(path)
    assert_equal 2, @status.exitstatus
    assert_no_disclosure('synthetic-heredoc')
  end
end
