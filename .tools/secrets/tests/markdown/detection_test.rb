# frozen_string_literal: true

require_relative 'helper'

# Existing value rules also inspect incomplete examples inside Markdown.
class SecretsMarkdownTest < SecretsMarkdownTestCase
  def test_complete_inline_values_keep_their_surroundings
    source = "Gebruik `Sensitive.new('synthetic-inline')` hier.\n"
    document = inspect_markdown(source)
    assert document.complete?
    assert_equal "Gebruik `Sensitive.new('[REDACTED]')` hier.\n", document.sanitized
  end

  def test_incomplete_inline_expressions_are_bounded_independently
    source = "Gebruik `Sensitive.new(join([` en `password = join(['synthetic-inline'` hier.\n\nUitleg.\n"
    document = inspect_markdown(source)
    assert document.complete?
    assert_equal "Gebruik `[REDACTED]` en `[REDACTED]` hier.\n\nUitleg.\n", document.sanitized
  end

  def test_fences_do_not_supply_expression_closers_from_later_fragments
    source = "```ruby\nSensitive.new(join(['synthetic-first'\n```\n\nUitleg.\n~~~\n]))\n~~~\n"
    document = inspect_markdown(source)
    assert document.complete?
    assert_equal "```ruby\n[REDACTED]\n```\n\nUitleg.\n~~~\n]))\n~~~\n", document.sanitized
  end

  def test_assignments_and_options_share_the_same_fallback
    ["password = join(['synthetic-value'", "tool --password join(['synthetic-value'",
     "tool --api-key=join(['synthetic-value'", "password = <<EOF\nsynthetic-value"].each do |expression|
      document = inspect_markdown("```\n#{expression}\n```\nUnrelated.\n")
      assert document.complete?, document.errors.inspect
      assert_equal "```\n[REDACTED]\n```\nUnrelated.\n", document.sanitized
    end
  end

  def test_all_languages_and_unlabelled_blocks_retain_detection
    ['', 'puppet', 'ruby', 'bash', 'yaml'].each do |language|
      source = "```#{language}\npassword = 'synthetic-one'\ntool --api-key synthetic-two\n```\n"
      document = inspect_markdown(source)
      assert document.complete?
      refute_includes document.sanitized, 'synthetic-one'
      refute_includes document.sanitized, 'synthetic-two'
      assert_includes document.sanitized, 'password = '
      assert_includes document.sanitized, 'tool --api-key '
    end
  end

  def test_utf8_crlf_long_delimiters_and_indentation_preserve_offsets
    source = "Üitleg ``password = join(['synthetic-é'``.\r\n  " \
             "~~~~bash\r\n--password 'synthetic-two'\r\n   ~~~~~ \t\r\nEinde."
    document = inspect_markdown(source, 'sample.MD')
    assert document.complete?
    assert_equal "Üitleg ``[REDACTED]``.\r\n  ~~~~bash\r\n--password '[REDACTED]'\r\n   ~~~~~ \t\r\nEinde.",
                 document.sanitized
    values = document.findings.select { |finding| finding[:kind] == 'value' }
    assert_equal [1, 3], values.map { |finding| finding[:line] }.uniq
  end

  def test_backticks_inside_fences_are_language_content
    document = inspect_markdown("````shell\npassword = `printf synthetic-command`\n```\n````\n")
    assert document.complete?
    refute_includes document.sanitized, 'synthetic-command'
    assert_includes document.sanitized, "\n```\n````\n"
  end

  def test_multiline_inline_code_keeps_its_exact_delimiters
    document = inspect_markdown("Uitleg ``password = join([\n'synthetic-value'`` einde.\n")
    assert document.complete?
    assert_equal "Uitleg ``[REDACTED]`` einde.\n", document.sanitized
  end

  def test_uncertain_boundaries_withhold_sanitized_content
    ["`password = join(['synthetic-value'", "```ruby\npassword = join(['synthetic-value'\n",
     "~~~~\npassword = join(['synthetic-value'\n~~~\n", '`password =` `synthetic-value`'].each do |source|
      document = inspect_markdown(source)
      refute document.complete?
      assert_raises(ArgumentError) { document.sanitized }
    end
  end

  def test_whole_document_signatures_are_not_limited_to_code_regions
    token = "ghp_#{'a' * 36}"
    source = "#{token}\n\n```\nhttps://reader:synthetic-url@example.org/path\n" \
             "-----BEGIN PRIVATE KEY-----\nsynthetic-key\n-----END PRIVATE KEY-----\n```\n"
    document = inspect_markdown(source)
    assert document.complete?
    [token, 'synthetic-url', 'synthetic-key'].each { |value| refute_includes document.sanitized, value }
    assert_equal %w[credential_url pem_material token_signature], document.findings.map { |finding|
      finding[:rule]
    }.uniq.sort
  end

  def test_non_markdown_and_embedded_yaml_keep_their_existing_semantics
    source = "`password = join(['synthetic-value'`\n"
    %w[sample.txt sample.pp sample.sh].each do |name|
      document = ProjectTools::Secrets::Scanner.documents({ name => source }, analysis: false).first
      refute document.complete?
    end
    document = ProjectTools::Secrets::Scanner.documents({ 'sample.yaml' => "example: #{source.to_json}\n" }).first
    assert document.complete?
    refute_includes document.sanitized, 'synthetic-value'
  end
end
