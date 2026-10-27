# frozen_string_literal: true

require_relative '../test_helper'

# General scanning bounds Puppet syntax without loading the Puppet runtime.
class PuppetBoundsTest < SecretsTest
  def test_general_scan_bounds_the_complete_counter_and_preserves_next_statement
    source = "#{fixture('counts.pp')}" \
             "$password = 'synthetic-following'\n$plain = 'visible'\n"
    path = write('counts.pp', source)
    scan(path)
    assert_complete_scan
    assert_empty @report['files'].first['errors']
    assert_masked('synthetic-following')
    assert_includes sanitized, "$plain = 'visible'"
    assert_equal source, File.read(path)
    assert_unreviewed
  end

  def test_lambda_bounds_with_strings_nested_calls_and_multiline_parameters
    sources = [
      "$api_keys = $items.map |$item, $index| { sprintf('%s,%s', $item, $index) }",
      "$api_keys = $items.map |\n  $item,\n  $index\n| {\n  " \
      "sprintf('%s,%s', [$item, $index].join(','), 'synthetic-body')\n}"
    ]
    sources.each_with_index { |source, index| assert_lambda_bounds(source, index) }
  end

  def assert_lambda_bounds(source, index)
    document = ProjectTools::Secrets::Document.new('input.pp', "#{source}\n$plain = 'visible'\n")
    ProjectTools::Secrets::TextScan.new(document).scan
    assert document.complete?, "case #{index}"
    assert_equal "$api_keys = '[REDACTED]'\n$plain = 'visible'\n", document.sanitized
  end

  def test_indexed_reference_before_if_else_statements
    source = <<~PUPPET
      $api_key_name = $api_key['name']
        if $enabled {
          $password = 'synthetic-then'
        } else {
          $password = 'synthetic-else'
        }
      $plain = 'visible'
    PUPPET
    check_statements(source)
  end

  def test_complete_lambdas_before_indented_if_statements
    source = "#{fixture('counts.pp')}  if $enabled {\n    $password = 'synthetic-next'\n  }\n"
    path = write('following.pp', source)
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-next')
    assert_includes sanitized, 'if $enabled'
  end

  def test_keys_reference_before_a_following_if
    source = "$duplicate_api_keys = $api_keys.keys\n  if $enabled { $plain = 'visible' }\n"
    path = write('keys.pp', source)
    scan(path)
    assert_complete_scan
    assert_includes sanitized, "if $enabled { $plain = 'visible' }"
  end

  def check_statements(source)
    path = write('statements.pp', source)
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-then', 'synthetic-else')
    assert_includes sanitized, 'if $enabled'
    assert_includes sanitized, "$plain = 'visible'"
  end

  def test_incomplete_lambdas_strings_and_uncertain_continuations_are_rejected
    sources = [
      '$api_keys = $items.map |$item, $index',
      '$api_keys = $items.map |$item, $index|',
      '$api_keys = $items.map |$item, $index| {',
      "$api_keys = $items.map |$item| { 'synthetic-unclosed }",
      "$api_key = first\n  unknown continuation\n",
      "$api_key = $item['name']\n  if incomplete\n"
    ]
    sources.each_with_index { |source, index| assert_withheld(source, index) }
  end

  def assert_withheld(source, index)
    path = write("broken-#{index}.pp", source)
    scan(path)
    assert_equal 2, @status.exitstatus, "case #{index}"
    refute @report['complete']
    assert_includes @report['files'].first['errors'], 'unbounded_sensitive_value'
    assert_equal source, File.read(path)
  end
end
