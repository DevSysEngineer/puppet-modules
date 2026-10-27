# frozen_string_literal: true

require_relative '../test_helper'
require_relative 'support'
# Keep protected regions and excluded constructs intact.
class ArrayLayoutProtectionTest < Minitest::Test
  include ArrayLayoutSupport

  def test_crlf_is_preserved_in_both_directions_and_inside_protected_strings
    assert_array_fix("$x = [\r\n  1,\r\n]\r\n", "$x = [1]\r\n")
    value = "'#{'é' * 57}'"
    assert_array_fix("$x = [#{value}]\r\n", "$x = [\r\n  #{value},\r\n]\r\n")
    code = "$x = [\r\n  'first\r\nsecond',\r\n]\r\n"
    assert_clean_passes(code)
  end

  def test_protected_content_has_diagnostics_only_for_proven_deviations
    clean = "$x = [ # Explain the values.\n  'a',\n  # Explain the next value.\n  'b',\n]\n"
    assert_clean_passes(clean)
    assert_clean_passes("$x = [\n  [1, 2], # Keep this comment.\n]\n")
    ["$x = [1, /* Keep this comment. */ 2]\n", "$x = ['a\nb']\n",
     "$x = [\n    'a', # Keep this comment.\n]\n"].each do |code|
      assert_preserved(code, [:warning], review: true)
    end
  end

  def test_protected_child_is_not_partially_rewritten
    code = "$x = [\n  [1,2], # Keep this comment.\n]\n"
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    refute_empty problems
    assert(problems.all? { |problem| problem[:kind] == :warning })
  end

  def test_heredocs_and_multiline_complex_expressions_are_preserved
    clean = "$x = [\n  @(TEXT),\n    hello\n    | TEXT\n]\n"
    assert_clean_passes(clean)
    invalid_layout = "$x = [@(TEXT)]\nhello\nTEXT\n"
    assert_preserved(invalid_layout, [:warning], review: true)
    complex = "$x = [\n  {\n    'name' => 1,\n  },\n]\n"
    assert_clean_passes(complex)
    assert_preserved(complex.sub('  {', '    {'), [:warning], review: true)
  end

  def test_types_indexing_and_resource_references_are_not_arrays
    assert_clean_passes("class example (Array[String] $x = [], Enum['a', 'b'] $y = 'a') {}\n")
    assert_clean_passes("$x = $facts['os']['name']\nPackage['curl', 'wget'] -> Service['web']\n")
  end

  def test_later_manual_case_does_not_hide_an_independent_fix
    code = "$a = [ 'first' ]\n$b = [1, /* Explain. */ 2]\n"
    problems, fixed = lint(code, fix: true)
    assert_equal "$a = ['first']\n$b = [1, /* Explain. */ 2]\n", fixed
    assert_equal(%i[fixed warning], problems.map { |problem| problem[:kind] })
    assert_equal([:warning], findings(fixed).map { |problem| problem[:kind] })
  end

  def test_syntax_errors_and_disabled_layout_never_trigger_array_fixes
    code = "$x = [1,\n"
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert(problems.any? { |problem| problem[:check] == :syntax })
    code = "$x = [\n  1,\n]\n"
    assert_equal code, lint_checks(code, [:double_quoted_strings], fix: true).last
  end

  def test_ignored_array_ranges_remain_unchanged
    code = "# lint:ignore:project_layout\n$x = [ 'first' ]\n# lint:endignore\n"
    assert_preserved(code, [:ignored])
    code = "$x = [1,\n  2, # lint:ignore:project_layout\n]\n"
    assert_preserved(code, [:warning], review: true)
  end
end
