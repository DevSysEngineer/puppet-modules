# frozen_string_literal: true

require_relative '../test_helper'

# Verify decisions made after other checks change expression spelling or structure.
class ArrayLayoutInteractionTest < Minitest::Test
  include LintTestSupport

  def test_variable_fix_crosses_the_compact_width_in_the_same_run
    name = 'v' * 54
    before = "$x = [\n  \"${#{name}}\",\n]\n"
    assert_empty findings(before, :project_layout)
    assert_fix(before, "$x = [$#{name}]\n", :only_variable_string, :project_layout)
  end

  def test_quote_fix_crosses_the_compact_width_in_the_same_run
    value = 'x' * 49
    before = "$x = [\n  '#{value}',\n  'true',\n]\n"
    assert_empty findings(before, :project_layout)
    assert_fix(before, "$x = ['#{value}', true]\n", :quoted_booleans, :project_layout)
  end

  def test_fact_fix_creates_complex_elements_after_initial_detection
    before = "$x = [$::osfamily]\n"
    assert_empty findings(before, :project_layout)
    assert_fix(before, "$x = [\n  $facts['os']['family'],\n]\n", :legacy_facts, :project_layout)
  end

  def test_reference_fixes_can_remove_the_original_array_anchors
    assert_fix("Notify['target'] -> [File['/z'], File['/a']]\n", "Notify['target'] -> File['/a', '/z']\n",
               :project_resource_references, :project_layout)
  end

  def test_trailing_comma_and_array_layout_agree_on_the_final_form
    assert_fix("$x = [\n  'first'\n]\n", "$x = ['first']\n", :trailing_comma, :project_layout)
    value = 'x' * 57
    assert_fix("$x = ['#{value}']\n", "$x = [\n  '#{value}',\n]\n", :trailing_comma, :project_layout)
  end

  def test_resolved_length_diagnostic_is_fixed_and_remaining_length_is_active
    value = 'x' * 70
    before = "$x = ['#{value}', '#{value}']\n"
    problems, fixed = lint_checks(before, %i[140chars project_layout], fix: true)
    assert_equal "$x = [\n  '#{value}',\n  '#{value}',\n]\n", fixed
    assert_equal([:fixed], length_kinds(problems))
    assert_clean_passes(fixed, %i[140chars project_layout])
  end

  def test_remaining_length_is_active
    value = 'x' * 150
    problems, fixed = lint_checks("$x = ['#{value}']\n", %i[140chars project_layout], fix: true)
    assert_equal "$x = [\n  '#{value}',\n]\n", fixed
    assert_equal([:warning], length_kinds(problems))
    assert_equal fixed, lint_checks(fixed, %i[140chars project_layout], fix: true).last
  end

  def length_kinds(problems)
    problems.filter_map { |problem| problem[:kind] if problem[:check] == :'140chars' }
  end

  def test_independent_expression_comma_fix_precedes_array_rendering
    assert_fix("$x = [call('first','second')]\n", "$x = [\n  call('first', 'second'),\n]\n", :project_layout)
  end

  def test_disabled_layout_keeps_the_existing_fix_selection
    before = "$x = [\n  \"${value}\",\n]\n"
    assert_fix(before, "$x = [\n  $value,\n]\n", :only_variable_string)
  end
end
