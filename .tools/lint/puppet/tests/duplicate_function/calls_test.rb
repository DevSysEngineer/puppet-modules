# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../duplicate_function_calls_support'

# Exercise structural grouping and native token corrections with synthetic manifests.
class DuplicateFunctionCallsTest < Minitest::Test
  include LintTestSupport
  include DuplicateFunctionCallsSupport

  RULE = :project_duplicate_function_calls

  def test_nextcloud_keeps_the_json_wrapper_comment_and_guard
    problems = findings(nextcloud)
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_match(/Repeated String\(\).*First occurrence at line 5\./, problems.first[:message])
    assert_fix(nextcloud, nextcloud(shared: true), count: 1)
  end

  def test_one_two_and_three_calls
    assert_clean_passes(resource('String(42)'))
    [2, 3].each do |count|
      before = resource(Array.new(count, 'String(42)'))
      after = "$string_result = String(42)\n#{resource(*Array.new(count, '$string_result'))}"
      assert_fix(before, after, count: 1)
    end
  end

  def test_whitespace_and_multiline_occurrences
    before = resource('String(42)', "String(\n    42\n  )")
    after = "$string_result = String(42)\n#{resource('$string_result', '$string_result')}"
    assert_fix(before, after, count: 1)
  end

  def test_different_function_arguments_order_and_types
    [['String(42)', 'Integer(42)'], ['String(42)', 'String(43)'],
     ['String(42)', 'String(42.0)'], ["String('a')", "String('b')"],
     ['String([1, 2])', 'String([2, 1])'],
     ["String({'a' => 1, 'b' => 2})", "String({'b' => 2, 'a' => 1})"],
     ["Integer('10', 10)", "Integer('10', 16)"],
     ["regsubst('ABC', 'a', 'x', 'G')", "regsubst('ABC', 'a', 'x', 'GI')"]].each do |calls|
      assert_clean_passes(resource(*calls))
    end
  end

  def test_nested_largest_group_and_independent_groups
    before = resource('String(abs(-42))', 'String(abs(-42))')
    after = "$string_result = String(abs(-42))\n#{resource('$string_result', '$string_result')}"
    assert_fix(before, after, count: 1)
    before = resource('String(42)', 'String(42)', 'abs(-2)', 'abs(-2)')
    after = "$string_result = String(42)\n$abs_result = abs(-2)\n" \
            "#{resource('$string_result', '$string_result', '$abs_result', '$abs_result')}"
    assert_fix(before, after, count: 2)
  end

  def test_suppression_on_any_occurrence_prevents_partial_fix
    code = "notify { 'example':\n  message => [\n    String(42), # lint:ignore:project_duplicate_function_calls\n    " \
           "String(42),\n  ],\n}\n"
    assert_preserved(code, [:warning])
    assert_preserved(
      "# lint:ignore:project_duplicate_function_calls\n#{resource('String(42)',
                                                                  'String(42)')}# lint:endignore\n", [:ignored]
    )
  end

  def test_forced_refusal_keeps_every_byte
    before = resource('String(42)', 'String(42) /* preserve explanation */')
    assert_preserved(before.sub('String(42)', 'String(/* preserve explanation */42)'), [:warning])
  end
end
