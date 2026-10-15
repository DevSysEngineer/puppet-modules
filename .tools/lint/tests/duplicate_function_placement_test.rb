# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'duplicate_function_calls_support'

# Preserve ownership of explanations while sharing only eagerly evaluated values.
class DuplicateFunctionPlacementTest < Minitest::Test
  include LintTestSupport
  include DuplicateFunctionCallsSupport

  RULE = :project_duplicate_function_calls

  def test_single_owner_keeps_the_whole_explanation_above_the_assignment
    ["# Report the converted value.\n", "# Report the converted value.\n# Keep both representations equal.\n",
     "/* Report the converted value.\n * Keep both representations equal. */\n"].each do |comment|
      before = comment + resource('String(42)', 'String(42)')
      after = "#{comment}$string_result = String(42)\n#{resource('$string_result', '$string_result')}"
      assert_fix(before, after, *LAYOUT, count: 1)
    end
  end

  def test_without_comment_only_fixes_when_no_group_explanation_is_required
    before = resource('String(42)', 'String(42)')
    assert_fix(before, "$string_result = String(42)\n#{resource('$string_result', '$string_result')}", *LAYOUT,
               count: 1)
    assert_preserved("if true {\n#{before}}\n", [:warning])
    assert_preserved("class example {\n#{before}}\n", [:warning])
  end

  def test_shared_conversion_precedes_each_first_resource_comment
    ["# Report another value.\n", "# Report the converted value.\n"].each do |comment|
      before = pair(comment: comment)
      after = "$string_result = String(42)\n\n#{pair(comment: comment, shared: true)}"
      assert_fix(before, after, *LAYOUT, count: 1)
    end
  end

  def test_group_includes_a_later_owner_after_two_calls_in_the_first
    before = pair(first: ['String(42)', 'String(42)'])
    after = "$string_result = String(42)\n\n#{pair(first: ['$string_result', '$string_result'], shared: true)}"
    assert_fix(before, after, *LAYOUT, count: 1)
  end

  def test_shared_group_at_block_start_refuses_to_invent_or_reassign_a_comment
    ["if true {\n", "class example {\n"].each do |opening|
      assert_preserved("#{opening}#{pair}}\n", [:warning])
    end
  end

  def test_shared_group_stays_local_after_its_dependency
    body = pair.gsub('String(42)', 'String($value)').lines.map do |line|
      line.strip.empty? ? "\n" : "  #{line}"
    end.join
    before = "if true {\n  # Select the value to report.\n  $value = 42\n\n#{body}}\n"
    after = before.sub('  # Report the converted', "  $value_string = String($value)\n\n  # Report the converted")
                  .sub('[String($value)]', '[$value_string]').sub('[String($value)]', '[$value_string]')
    assert_fix(before, after, *LAYOUT, count: 1)
  end

  def test_shared_nextcloud_resources_keep_the_existing_enclosing_expression_preference
    body = nextcloud.lines[2...-2].join
    second = body.sub('${name}_files_max_chunk_size', '${name}_files_max_chunk_size2')
    before = nextcloud.sub(body, "    notice('ready')\n\n#{body}\n#{second}")
    declarations = "    $files_max_chunk_size_string = String($files_max_chunk_size)\n\n    " \
                   "$files_max_chunk_size_json = stdlib::to_json(String($files_max_chunk_size))\n\n"
    after = before.gsub("'--value', String($files_max_chunk_size)", "'--value', $files_max_chunk_size_string")
                  .gsub('unless_json  => stdlib::to_json(String($files_max_chunk_size))',
                        'unless_json  => $files_max_chunk_size_json')
                  .sub('    # Compare', "#{declarations}    # Compare")
    assert_fix(before, after, *LAYOUT, count: 2)
  end

  def test_later_shared_group_accounts_for_dependencies_introduced_by_an_earlier_fix
    before = dependent_group_input
    assert_detected(before, LAYOUT)
    problems, fixed = lint_checks(before, LAYOUT, fix: true)
    assert_equal(%i[fixed warning], problems.map { |problem| problem[:kind] })
    assert_equal dependent_group_input(shared: true), fixed
    Puppet::Pops::Parser::EvaluatingParser.new.parse_string(fixed, 'example.pp')
  end

  def test_remaining_shared_group_is_stable_and_has_no_other_layout_warnings
    fixed = dependent_group_input(shared: true)
    assert_clean_passes(fixed, LAYOUT - [RULE])
    [false, true].each { |fix| assert_preserved(fixed, [:warning], fix: fix) }
  end

  def dependent_group_input(shared: false)
    prefix = "# Prepare the reported value.\n$value = 42\n\n"
    prefix += "$value_string = String($value)\n\n" if shared
    call = shared ? '$value_string' : 'String($value)'
    prefix + pair(first: [call, 'abs(-2)']).sub('[String(42)]', "[#{call}, abs(-2)]")
  end
end
