# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'duplicate_function_calls_support'

# Unknown bindings and conditional execution must never be made eager.
class DuplicateFunctionSafetyTest < Minitest::Test
  include LintTestSupport
  include DuplicateFunctionCallsSupport

  RULE = :project_duplicate_function_calls

  def test_unknown_arguments_and_excluded_calls
    ['String(lookup(\'example::value\'))', 'String(Sensitive(42))', 'String(Deferred(\'x\', []))',
     'String($1)', 'String($unknown)', "example::convert('x')", 'Integer(42, 3)',
     "abs('2')", 'Array(42)', 'String(42) |$x| { $x }'].each do |call|
      assert_clean_passes(resource(call, call))
    end
  end

  def test_prior_typed_lookup_is_not_moved
    prefix = "$chunk_size = lookup('example::chunk_size', Integer)\n"
    before = prefix + resource('String($chunk_size)', 'String($chunk_size)')
    after = "#{prefix}$chunk_size_string = String($chunk_size)\n\n" \
            "#{resource('$chunk_size_string', '$chunk_size_string')}"
    assert_fix(before, after, count: 1)
  end

  def test_unknown_parameter_contents_and_later_assignment
    code = "class example($value) {\n#{resource('String($value)', 'String($value)')}}\n"
    assert_clean_passes(code)
    assert_clean_passes("#{resource('String($later)', 'String($later)')}$later = 42\n")
  end

  def test_no_cross_branch_or_scope_grouping
    assert_clean_passes("if true {\n#{resource('String(42)')}} else {\n#{resource('String(42)')}}\n")
    assert_clean_passes("class one {\n#{resource('String(42)')}}\nclass two {\n#{resource('String(42)')}}\n")
    assert_clean_passes("[1, 2].each |$x| {\n#{resource('String(42)', 'String(42)')}}\n")
  end

  def test_short_circuit_and_selector_do_not_create_eager_calls
    ['false and Integer(\'invalid\')', 'true or Integer(\'invalid\')',
     'true ? { true => 1, false => Integer(\'invalid\') }'].each do |expression|
      assert_clean_passes(resource(expression, expression))
    end
  end

  def test_conflicting_and_previously_unbound_names_refuse_without_mutation
    ["$string_result = 'existing'\n", "notice($string_result)\n"].each do |prefix|
      assert_preserved(prefix + resource('String(42)', 'String(42)'), [:warning])
    end
  end

  def test_unknown_earlier_evaluation_and_effect_between_calls_refuse
    code = resource('String(42)', 'String(42)').sub("'example'", "lookup('example::title')")
    assert_preserved(code, [:warning])
    assert_preserved(resource('String(42)', "notice('event')", 'String(42)'), [:warning])
    assert_preserved(resource("Integer('invalid')", 'String(42)', 'String(42)'), [:warning])
  end

  def test_comment_and_string_text_are_not_calls
    assert_clean_passes("# String(42) String(42)\n#{resource("'String(42) String(42)'")}")
    assert_clean_passes(resource('"${String(42)} ${String(42)}"'))
  end
end
