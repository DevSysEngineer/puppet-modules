# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'duplicate_function_calls_support'

# Refuse ambiguous explanations, dependencies and execution paths before mutation.
class DuplicateFunctionPlacementSafetyTest < Minitest::Test
  include LintTestSupport
  include DuplicateFunctionCallsSupport

  RULE = :project_duplicate_function_calls

  def test_special_comments_are_not_rebound
    ['# @summary Reports a value.', '# @api private', '# fmt: off', '# prettier-ignore',
     '# SPDX-License-Identifier: Apache-2.0', '# Copyright 2026 Example',
     '# This file is managed by Puppet.', '# lint:ignore:140chars'].each do |directive|
      before = "# Report the converted value.\n#{directive}\n" + resource('String(42)', 'String(42)')
      before += "# lint:endignore\n" if directive.include?('lint:ignore')
      assert_preserved(before, [:warning])
    end
  end

  def test_suppression_on_the_later_owner_refuses_the_whole_group
    code = "#{pair.sub('# Report another value.', '# lint:ignore:project_duplicate_function_calls')}# lint:endignore\n"
    assert_preserved(code, [:ignored])
    code = pair(first: ['String(42)', 'String(42)'])
           .sub('# Report another value.', '# lint:ignore:project_duplicate_function_calls')
    code += "# lint:endignore\n"
    assert_preserved(code, [:warning])
  end

  def test_active_other_suppression_preserves_scope
    code = "# lint:ignore:140chars\n\n# Report the converted value.\n#{resource('String(42)',
                                                                                'String(42)')}# lint:endignore\n"
    assert_preserved(code, [:warning])
  end

  def test_detached_directive_is_not_attached_to_the_new_assignment
    before = "# prettier-ignore\n\n# Report the converted value.\n#{resource('String(42)', 'String(42)')}"
    assert_preserved(before, [:warning])
  end

  def test_prior_code_blank_lines_and_inline_comments_keep_their_binding
    prefix = "notice('ready') # Keep this inline explanation.\n\n"
    before = prefix + pair
    after = "#{prefix}$string_result = String(42)\n\n#{pair(shared: true)}"
    assert_fix(before, after, *LAYOUT, count: 1)
    before = "#{prefix}# Report the converted value.\n#{resource('String(42)', 'String(42)')}"
    before = before.sub("],\n", "], # Preserve the attribute explanation.\n")
    after = before.sub('notify {', "$string_result = String(42)\nnotify {")
                  .sub('[String(42), String(42)]', '[$string_result, $string_result]')
    assert_fix(before, after, *LAYOUT, count: 1)
  end

  def test_distinct_execution_paths_and_lambda_bindings_do_not_group
    one = resource('String(42)')
    assert_clean_passes("if true {\n#{one}} elsif false {\n#{one}} else {\n#{one}}\n")
    assert_clean_passes("case $choice { 'one': {\n#{one}} default: {\n#{one}} }\n")
    assert_clean_passes("[1].each |$x| {\n#{one}}\n[2].each |$x| {\n#{one}}\n")
    assert_clean_passes("if true {\n#{one}}\n#{one}")
    assert_clean_passes("class one {\n#{one}}\nclass two {\n#{one}}\n")
  end

  def test_different_bindings_are_not_shared
    code = "if true {\n  $value = 1\n#{resource('String($value)')}} else {\n  " \
           "$value = 2\n#{resource('String($value)')}}\n"
    assert_clean_passes(code)
  end

  def test_existing_names_and_evaluation_effects_refuse_before_any_change
    assert_preserved("$string_result = 'existing'\n\n#{pair}", [:warning])
    assert_preserved(pair.sub("'example'", "lookup('example::title')"), [:warning])
    assert_preserved(pair.sub('[String(42)]', "[notice('event'), String(42)]"), [:warning])
  end

  def test_unknown_evaluations_and_control_flow_between_owners_refuse
    ["notice('event')", "if true { notice('event') }", '[1].each |$value| { notice($value) }',
     "notify { 'middle': message => notice('event') }"].each do |statement|
      assert_preserved(pair.sub("\n}\n\n", "\n}\n#{statement}\n\n"), [:warning])
    end
    assert_preserved(pair(first: ['String(42)', "notice('event')"]), [:warning])
  end

  def test_unexplained_independent_assignment_after_a_dependent_group_refuses
    prefix = "# Prepare the reported values.\n$value = 42\n$text = String($value)\n\n"
    assert_preserved(prefix + pair, [:warning])
    assert_preserved(prefix + resource('String(7)', 'String(7)'), [:warning])
  end

  def test_multiple_groups_keep_the_single_owner_explanation
    comment = "# Report both converted values.\n"
    before = comment + resource('String(42)', 'String(42)', 'abs(-2)', 'abs(-2)')
    converted = resource('$string_result', '$string_result', '$abs_result', '$abs_result')
    after = "#{comment}$string_result = String(42)\n$abs_result = abs(-2)\n#{converted}"
    assert_fix(before, after, *LAYOUT, count: 2)
  end

  def test_only_one_owner_without_comments_preserves_prior_inline_comment
    prefix = "notice('ready') # Preserve this explanation.\n\n"
    before = prefix + resource('String(42)', 'String(42)')
    after = "#{prefix}$string_result = String(42)\n#{resource('$string_result', '$string_result')}"
    assert_fix(before, after, *LAYOUT, count: 1)
  end

  def test_shared_calls_without_resource_comments_need_no_extra_separator
    before = resource('String(42)') + resource('String(42)').sub("'example'", "'other'")
    after = "$string_result = String(42)\n#{before.gsub('String(42)', '$string_result')}"
    assert_fix(before, after, count: 1)
  end
end
