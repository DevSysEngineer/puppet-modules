# frozen_string_literal: true

require_relative 'test_helper'

# Keep attribute boundaries compact without rewriting values or explanatory blocks.
class ResourceAttributeSpacingTest < Minitest::Test
  include LintTestSupport

  RULE = :project_layout

  def test_reports_both_resource_attribute_gaps_at_the_first_blank_line
    before = "mysql::database { $database_name:\n\n  ensure => present,\n\n  test   => 'haha',\n}\n"
    problems = findings(before)
    assert_equal([2, 4], problems.map { |problem| problem[:line] })
    assert(problems.all? { |problem| problem[:kind] == :warning && problem[:column] == 1 })
    assert(problems.all? { |problem| problem[:message] == 'Remove blank lines before resource attributes' })
    assert_fix before, before.gsub("\n\n", "\n"), count: 2
  end

  def test_fixes_all_resource_forms_without_duplicate_opening_brace_findings
    ["notify { 'example':", "@notify { 'example':", "@@notify { 'example':", "class { 'example':",
     'Notify {', "Notify['example'] {", "Notify <| title == 'example' |> {",
     "Notify <<| title == 'example' |>> {"].each do |opening|
      before = "#{opening}\n\n  message  => 'Example',\n\n  withpath => false,\n}\n"
      assert_fix before, before.gsub("\n\n", "\n"), count: 2
    end
  end

  def test_removes_whitespace_only_lines_and_preserves_line_endings
    ["\n", "\r\n"].each do |newline|
      before = "notify { 'example':\n \t\n\n  message => 'Example',\n}\n".gsub("\n", newline)
      after = "notify { 'example':\n  message => 'Example',\n}\n".gsub("\n", newline)
      assert_fix before, after, count: 1
    end
  end

  def test_keeps_separation_between_resource_bodies_and_handles_multiline_titles
    before = "notify {\n  'first':\n\n    message => 'First';\n\n  'second':\n\n    message => 'Second';\n}\n"
    after = "notify {\n  'first':\n    message => 'First';\n\n  'second':\n    message => 'Second';\n}\n"
    assert_fix before, after, count: 2
    before = "notify { lookup(\n  'example::title',\n):\n\n  message => 'Example',\n}\n"
    assert_fix before, before.sub("):\n\n", "):\n"), count: 1
  end

  def test_keeps_inline_comments_attached_to_their_original_lines
    before = "notify { 'example': # Explain the title.\n\n  " \
             "message => 'Example', /* Explain the value. */\n\n  * => $attributes,\n}\n"
    assert_fix before, before.gsub("\n\n", "\n"), count: 2
  end

  def test_preserves_standalone_explanations_and_unrelated_block_spacing
    code = "notify { 'example':\n\n  # Explain the message.\n  message => 'Example',\n\n  " \
           "# Explain the path.\n  withpath => false,\n}\n"
    assert_clean_passes code, %i[project_layout project_comment_spacing]
    assert_clean_passes "if $active {\n  notice('First')\n\n  notice('Second')\n}\n"
    assert_clean_passes "notify { 'example':\n}\n"
  end

  def test_preserves_nested_value_spacing_and_multiline_literal_contents
    before = "example { 'item':\n\n  settings => {\n    'first' => 'value',\n\n    'second' => 'value',\n  },\n\n  " \
             "message => \"first\n\nsecond\",\n\n  * => $attributes,\n}\n"
    after = before.sub("'item':\n\n", "'item':\n").sub("},\n\n", "},\n").sub("second\",\n\n", "second\",\n")
    assert_fix before, after, count: 3
  end

  def test_preserves_heredoc_data_while_fixing_the_next_attribute_gap
    before = <<~PUPPET
      notify { 'example':
        message => @(END),
      first

      second
      END

        withpath => false,
      }
    PUPPET
    assert_fix before, before.sub("END\n\n", "END\n"), count: 1
  end

  def test_native_suppression_and_check_selection_preserve_source
    body = "notify { 'example':\n\n  message => 'Example',\n}\n"
    code = "# lint:ignore:project_layout\n#{body}# lint:endignore\n"
    problems, fixed = lint(code, fix: true)
    assert_equal([:ignored], problems.map { |problem| problem[:kind] })
    assert_equal code, fixed
    assert_clean_passes body, [:arrow_alignment]
  end

  def test_interacts_with_quotes_alignment_indentation_and_array_fixes
    before = "    notify { 'example':\n\n    message => \"Example\",\n\n    withpath => false,\n    " \
             "tag => [\n      'one',\n      'two',\n    ],\n}\n"
    after = "notify { 'example':\n  message  => 'Example',\n  withpath => false,\n  tag      => ['one', 'two'],\n}\n"
    assert_fix before, after, :project_layout, :double_quoted_strings, :arrow_alignment, :'2sp_soft_tabs',
               :trailing_comma
  end
end
