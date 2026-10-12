# frozen_string_literal: true

require_relative 'markdown_helper'

# Raw HTML and containers cannot lend Markdown boundaries to secret expressions.
class SecretsMarkdownOpaqueTest < SecretsMarkdownTestCase
  def test_uncertain_indentation_keeps_the_ambiguous_continuation_guard
    source = "    password = synthetic-head\n   synthetic-tail\n"
    document = inspect_markdown(source)
    refute document.complete?
    assert_includes document.errors, 'unbounded_sensitive_value'
    assert_raises(ArgumentError) { document.sanitized }
  end

  def test_backticks_in_html_attributes_do_not_truncate_a_value
    source = %q(Text <span title="`password = 'synthetic-head`synthetic-tail'">example</span>)
    document = inspect_markdown(source)
    assert document.complete?
    refute_includes document.sanitized, 'synthetic-head'
    refute_includes document.sanitized, 'synthetic-tail'
  end

  def test_raw_html_prevents_fragment_fallback_for_its_remaining_content
    source = "<script>\n\n```\npassword = join(['synthetic-value'\n```\n</script>\n"
    document = inspect_markdown(source)
    refute document.complete?
    assert_raises(ArgumentError) { document.sanitized }
  end

  def test_link_titles_do_not_lend_backtick_boundaries_to_values
    sources = [
      %q([example](https://example.org "`password = 'synthetic-head`synthetic-tail'")),
      %q([example]: https://example.org "`password = 'synthetic-head`synthetic-tail'")
    ]
    sources.each do |source|
      document = inspect_markdown(source)
      assert document.complete?
      refute_includes document.sanitized, 'synthetic-head'
      refute_includes document.sanitized, 'synthetic-tail'
    end
  end

  def test_html_inside_fenced_code_does_not_change_the_outer_boundaries
    source = "```html\n<span>\npassword = join(['synthetic-value'\n```\nUnrelated.\n"
    document = inspect_markdown(source)
    assert document.complete?
    assert_equal "```html\n[REDACTED]\n```\nUnrelated.\n", document.sanitized
  end

  def test_unclosed_fragments_in_unsupported_containers_remain_blocked
    ['> ', '- ', '1. ', '# '].each do |prefix|
      document = inspect_markdown("#{prefix}`password = join(['synthetic-value'`\n")
      refute document.complete?
      assert_raises(ArgumentError) { document.sanitized }
    end
  end
end
