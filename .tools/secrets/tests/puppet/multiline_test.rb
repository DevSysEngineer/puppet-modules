# frozen_string_literal: true

require_relative '../test_helper'

# Literal offsets must cover complete data, including Unicode and multiline strings.
class PuppetMultilineTest < SecretsTest
  def test_heredoc_value_is_fully_masked
    source = <<~PUPPET
      $password = @(END)
      synthetic-first
      synthetic-last
      END
    PUPPET
    assert_puppet_redaction(source, %w[first last])
  end

  def test_pem_and_tokens_are_detected_without_sensitive_names
    source = <<~PUPPET
      $data = '-----BEGIN PRIVATE KEY-----
      synthetic-pem-body
      -----END PRIVATE KEY-----'
      $other = 'ghp_#{'x' * 36}'
    PUPPET
    assert_puppet_redaction(source, ['pem-body'])
    refute_includes sanitized, 'ghp_'
  end

  def test_unicode_multiline_and_literal_index_values
    source = <<~PUPPET
      # ééé
      $password = 'synthetic-first
      synthetic-second'
      $token = ['synthetic-index'][0]
      $secret = "synthetic-prefix${reference}"
    PUPPET
    assert_puppet_redaction(source, %w[first second index prefix])
  end
end
