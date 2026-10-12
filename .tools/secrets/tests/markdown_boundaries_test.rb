# frozen_string_literal: true

require_relative 'markdown_helper'

# Conservative boundaries retain inspection coverage and safe references.
class SecretsMarkdownBoundariesTest < SecretsMarkdownTestCase
  def test_adjacent_fences_keep_all_values_and_intervening_prose
    source = "```\npassword = join(['synthetic-one'\n```\nUitleg.\n~~~\npassword = 'synthetic-two'\n~~~\n"
    document = inspect_markdown(source)
    assert document.complete?
    assert_equal "```\n[REDACTED]\n```\nUitleg.\n~~~\npassword = '[REDACTED]'\n~~~\n", document.sanitized
  end

  def test_ordinary_text_after_inline_code_retains_detection
    source = "Zie `ordinary` en password = 'synthetic-value'\n\nUitleg.\n"
    document = inspect_markdown(source)
    assert document.complete?
    assert_equal "Zie `ordinary` en password = '[REDACTED]'\n\nUitleg.\n", document.sanitized
  end

  def test_inline_authorization_and_encrypted_values_are_still_masked
    source = "`Bearer synthetic-authorization-value` en `ENC[synthetic-encrypted-value]`.\n"
    document = inspect_markdown(source)
    assert document.complete?
    assert_equal "`Bearer [REDACTED]` en `[REDACTED]`.\n", document.sanitized
  end

  def test_indented_examples_are_inspected_without_assuming_container_boundaries
    document = inspect_markdown("Uitleg.\n\n    password = 'synthetic-value'\n\nEinde.\n")
    assert document.complete?
    assert_equal "Uitleg.\n\n    password = '[REDACTED]'\n\nEinde.\n", document.sanitized
    document = inspect_markdown("    password = join(['synthetic-value'\n\n])\n")
    refute document.complete?
    document = inspect_markdown("\tpassword = 'synthetic-value'\n")
    assert document.complete?
    refute_includes document.sanitized, 'synthetic-value'
  end

  def test_lookups_and_references_remain_indicators
    source = "`Sensitive.new(lookup('example::password', Sensitive[String]))` en `password = $value`.\n"
    document = inspect_markdown(source)
    assert document.complete?
    assert_equal source, document.sanitized
    refute(document.findings.any? { |finding| finding[:kind] == 'value' })
  end

  def test_incomplete_signatures_still_block_even_in_a_closed_fragment
    source = "```\npassword = join([\n-----BEGIN PRIVATE KEY-----\nsynthetic-key\n```\n"
    document = inspect_markdown(source)
    refute document.complete?
    assert_includes document.errors, 'unterminated_pem_material'
    assert_raises(ArgumentError) { document.sanitized }
  end

  def test_overlapping_fallback_and_signature_spans_cover_the_whole_fragment
    token = "ghp_#{'b' * 36}"
    source = "```\npassword = join(['synthetic-value'\n#{token}\n```\n"
    document = inspect_markdown(source)
    assert document.complete?
    assert_equal "```\n[REDACTED]\n```\n", document.sanitized
    assert_equal 1, document.merged_spans.length
  end

  def test_inline_delimiters_require_equal_runs_and_do_not_honor_internal_escapes
    source = "Gebruik ``password = join(['synthetic-value' ` smaller`` hier.\n"
    document = inspect_markdown(source)
    assert document.complete?
    assert_equal "Gebruik ``[REDACTED]`` hier.\n", document.sanitized
    document = inspect_markdown("`password = join(['synthetic-value'\\` einde.\n")
    assert document.complete?
    assert_equal "`[REDACTED]` einde.\n", document.sanitized
    document = inspect_markdown("\\`password = join(['synthetic-value'` einde.\n")
    refute document.complete?
  end

  def test_prose_and_fragment_boundaries_do_not_hide_split_assignments
    ['password = `synthetic-value`', '`password = `synthetic-value',
     '`tool --password ` synthetic-value', "`password = join([`\n\n])"].each do |source|
      document = inspect_markdown(source)
      if source.start_with?('`password = join([')
        assert document.complete?
        assert_equal "`[REDACTED]`\n\n])", document.sanitized
      else
        refute document.complete?
      end
    end
  end
end
