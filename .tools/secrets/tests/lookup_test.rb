# frozen_string_literal: true

require_relative 'test_helper'

# References remain readable while local YAML and literal defaults stay protected.
class SecretsLookupTest < SecretsTest
  REFERENCES = [
    "lookup('sample::password', Sensitive[String])",
    'lookup("sample::password", Sensitive[String])',
    "lookup(\n  'sample::password',\n  Sensitive[ String ]\n)",
    "Sensitive(lookup('sample::password', Sensitive[String]))"
  ].freeze
  VALUE = 'synthetic-test-credential'
  YAML_SOURCE = "sample::password: '#{VALUE}'\n"
  LITERALS = [
    "lookup('sample::password', Sensitive[String], 'first', '#{VALUE}')",
    "lookup('sample::password', { 'default_value' => '#{VALUE}' })",
    "lookup('sample::password', Sensitive[Enum['#{VALUE}']])",
    "lookup('sample::password', Sensitive[String]) + '#{VALUE}'"
  ].freeze

  def test_typed_lookup_preserves_the_reference_and_only_reports_indicators
    REFERENCES.each_with_index do |expression, index|
      source = manifest(expression)
      path = write("reference-#{index}.pp", source)
      scan_copy(path, index)
      assert_equal source, copy
      assert_equal ['indicator'], kinds
      assert_equal source, File.read(path)
    end
  end

  def test_yaml_value_is_masked_while_the_typed_lookup_stays_readable
    source = manifest(REFERENCES.first)
    reference = write('reference.pp', source)
    data = write('data.yaml', YAML_SOURCE)
    scan('--redact', @copies, reference, data)
    assert_complete_copy
    assert_equal source, copy
    assert_equal ['indicator'], kinds
    assert_includes kinds(1), 'value'
    assert_masked(VALUE, index: 1)
    assert_equal YAML_SOURCE, File.read(data)
  end

  def test_lookup_expressions_with_literal_values_are_still_masked
    LITERALS.each_with_index do |expression, index|
      path = write("literal-#{index}.pp", "password => #{expression},\n")
      scan_copy(path, index)
      assert_masked(VALUE)
      assert_includes kinds, 'value'
    end
  end

  private

  def manifest(expression)
    "mysql::user { 'sample':\n  password => #{expression},\n}\n"
  end

  def scan_copy(path, index)
    @copies = File.join(@directory, "copies-#{index}")
    scan('--redact', @copies, path)
    assert_complete_copy
  end

  def kinds(index = 0)
    @report.fetch('files').fetch(index).fetch('findings').map { |item| item['kind'] }.uniq
  end
end
