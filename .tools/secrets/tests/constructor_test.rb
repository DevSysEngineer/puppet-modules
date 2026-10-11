# frozen_string_literal: true

require_relative 'test_helper'

# Both public Puppet constructors must use the same generic masking boundaries.
class SecretsConstructorTest < SecretsTest
  def test_generic_scan_masks_sensitive_new_without_a_sensitive_field_name
    path = write('input.pp', "$data = Sensitive.new('synthetic-constructor-first\nsynthetic-constructor-last')\n")
    scan('--redact', @copies, path)
    assert_complete_copy
    assert_masked('synthetic-constructor-first', 'synthetic-constructor-last')
    assert_includes copy, "Sensitive.new('[REDACTED]')"
  end

  def test_generic_scan_preserves_typed_lookup_inside_sensitive_new
    source = "$data = Sensitive.new(lookup('example::password', Sensitive[String]))\n"
    path = write('input.pp', source)
    scan('--redact', @copies, path)
    assert_complete_copy
    assert_equal source, copy
    refute(@report['files'].first['findings'].any? { |finding| finding['kind'] == 'value' })
  end
end
