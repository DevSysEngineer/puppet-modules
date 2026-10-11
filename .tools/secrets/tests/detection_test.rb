# frozen_string_literal: true

require_relative 'test_helper'

# Detection evidence and redaction boundaries for supported text and Puppet input.
class SecretsDetectionTest < SecretsTest
  def test_plaintext_and_puppet_values_are_masked_without_changing_originals
    text = fixture('assignments.txt')
    path = write('example.pp', text)
    scan('--redact', @copies, path)
    assert_complete_copy
    assert_equal text, File.read(path)
    assert_includes copy, "Sensitive('[REDACTED]')"
    assert_includes copy, 'token => $from_hiera'
    assert_includes copy, "$ordinary = 'unchanged'"
    assert_masked('synthetic-first', 'synthetic-second', 'synthetic-third')
  end

  def test_multiline_strings_nested_sensitive_and_complete_pem_blocks
    text = fixture('multiline.txt')
    path = write('settings.pp', text)
    scan('--redact', @copies, path)
    assert_equal 1, @status.exitstatus, @out + @err
    %w[synthetic-line-one synthetic-line-two synthetic-nested synthetic-array synthetic-key-body].each do |value|
      refute_includes copy, value
      assert_no_disclosure(value)
    end
    assert_includes copy, "Sensitive('[REDACTED]')"
  end

  def test_indicator_is_not_reported_as_a_literal_value
    path = write('params.pp', "Sensitive[String] $password,\n$token = lookup('example::credential')\n")
    scan(path)
    assert_equal 1, @status.exitstatus
    assert @report['complete']
    assert(@report['files'][0]['findings'].all? { |item| item['kind'] == 'indicator' })
  end

  def test_known_tokens_authorization_urls_and_ciphertext_without_sensitive_names
    values = ["ghp_#{'a' * 30}", "sk-proj-#{'b' * 30}", "glpat-#{'c' * 25}",
              'synthetic-bearer', 'synthetic-basic', 'synthetic-user:synthetic-pass', 'synthetic-ciphertext']
    text = "#{values[0]}\n#{values[1]}\n#{values[2]}\nBearer #{values[3]}\nBasic #{values[4]}\n" \
           "https://#{values[5]}@example.org/path\nENC[PKCS7,#{values[6]}]\n"
    path = write('opaque.txt', text)
    scan('--redact', @copies, path)
    assert_equal 1, @status.exitstatus, @out + @err
    assert_masked(*values)
  end

  def test_unterminated_values_block_every_copy
    ["password = 'synthetic-unclosed\n", "-----BEGIN PRIVATE KEY-----\nsynthetic-unclosed\n",
     "key: ENC[synthetic-unclosed\n", "password => @(END)\nsynthetic-unclosed\nEND\n"].each do |text|
      path = write('broken.txt', text)
      scan('--redact', @copies, path)
      assert_equal 2, @status.exitstatus, @out + @err
      refute @report['complete']
      refute_path_exists @copies
      assert_no_disclosure('synthetic-unclosed')
    end
  end

  def test_utf8_offsets_and_line_numbers
    path = write('unicode.pp', "# café\n$password = 'synthetic-unicode'\n")
    scan('--redact', @copies, path)
    assert_equal 1, @status.exitstatus, @out + @err
    assert_includes copy, '# café'
    refute_includes copy, 'synthetic-unicode'
    assert(@report['files'][0]['findings'].all? { |item| item['line'] == 2 })
  end
end
