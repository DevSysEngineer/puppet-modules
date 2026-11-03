# frozen_string_literal: true

require_relative 'test_helper'

# Structural resource indentation must not depend on whitespace parity.
class ResourceIndentationTest < Minitest::Test
  include LintTestSupport

  RULE = :'2sp_soft_tabs'
  SCOPES = [
    ['', '', 0], ["class example {\n", "}\n", 2], ["define example {\n", "}\n", 2],
    ["node default {\n", "}\n", 2], ["if $active {\n", "}\n", 2],
    ["unless $active {\n", "}\n", 2], ["if $active {} else {\n", "}\n", 2],
    ["if $active {} elsif $fallback {\n", "}\n", 2],
    ["[1].each |$value| {\n", "}\n", 2],
    ["class example {\n  if $active {\n", "  }\n}\n", 4],
    ["case $state {\n  default: {\n", "  }\n}\n", 4]
  ].freeze

  def test_corrects_the_reported_resource_without_changing_its_comment
    before = "# Create database for this server\n    mysql::database { $database_name:\n    ensure => present,\n}\n"
    after = "# Create database for this server\nmysql::database { $database_name:\n  ensure => present,\n}\n"
    assert_equal [2, 3], finding_lines(before)
    assert_fix before, after, count: 2
  end

  def test_checks_resource_levels_in_supported_statement_scopes
    SCOPES.each do |opening, closing, width|
      correct = "#{' ' * width}notify { 'example':\n#{' ' * (width + 2)}message => 'hello',\n#{' ' * width}}\n"
      wrong = correct.lines.map { |line| "  #{line}" }.join
      assert_fix opening + wrong + closing, opening + correct + closing, count: 3
    end
  end

  def test_covers_native_defined_class_virtual_exported_default_and_override_resources
    ["notify { 'example':", 'mysql::database { $database_name:', "class { 'example':",
     "@notify { 'example':", "@@notify { 'example':", 'File {', "File['example'] {",
     'File <| |> {'].each do |opening|
      before = "    #{opening}\nensure => present,\n  }\n"
      after = "#{opening}\n  ensure => present,\n}\n"
      refute_empty findings(before), opening
      assert_fix before, after, count: 3
    end
  end

  def test_indents_separate_resource_titles_and_each_body
    before = "notify {\n'a':\nmessage => 'one';\n'b':\nmessage => 'two';\n}\n"
    after = "notify {\n  'a':\n    message => 'one';\n  'b':\n    message => 'two';\n}\n"
    assert_fix before, after, count: 4
  end

  def test_handles_odd_and_missing_indentation_without_duplicate_diagnostics
    before = " notify { 'example':\nmessage => 'hello',\n   }\n"
    after = "notify { 'example':\n  message => 'hello',\n}\n"
    assert_equal [1, 2, 3], finding_lines(before).sort
    assert_fix before, after, count: 3
  end

  def test_preserves_inline_resources_continuations_comments_and_literal_contents
    sources = [
      "notify { 'example': message => 'hello' }\n",
      "if $active { notify { 'example':\n    message => 'hello',\n  } }\n",
      "notify { 'example':\n  message => join(\n      ['one', 'two'],\n      ' ',\n  ),\n}\n",
      "notify { 'example':\n  # Keep the explanation.\n  message => 'one\n    two\nzero',\n}\n",
      "notify { 'example':\n  message => @(END),\n    keep these spaces\nzero\n  | END\n}\n",
      "notify {\n  ['one', 'two']:\n    message => 'hello',\n}\n"
    ]
    sources.each { |code| assert_clean_passes code }
  end

  def test_keeps_native_selection_suppressions_and_unproven_odd_indent_behavior
    code = "    notify { 'example':\n    message => 'hello',\n}\n"
    assert_clean_passes code, [:hard_tabs]
    ignored = "# lint:ignore:2sp_soft_tabs\n#{code}# lint:endignore\n"
    problems, fixed = lint(ignored, fix: true)
    assert(problems.all? { |problem| problem[:kind] == :ignored })
    assert_equal ignored, fixed
    assert_preserved "if $active {\n   notice('hello')\n}\n", [:error]
  end

  def test_resource_title_arrays_remain_consistent_with_array_layout_fixes
    before = "notify { [\n    'one',\n    'two',\n  ]:\n    message => 'hello',\n}\n"
    after = "notify { ['one', 'two']:\n  message => 'hello',\n}\n"
    assert_fix before, after, RULE, :project_layout
  end

  def test_title_changes_replan_attribute_arrays_at_the_line_width_boundary
    attribute = "#{'m' * 75} => ['#{'x' * 25}', '#{'y' * 25}'],\n"
    before = "notify { [\n    'one',\n    'two',\n  ]:\n    #{attribute}}\n"
    after = "notify { ['one', 'two']:\n  #{attribute}}\n"
    assert_equal 140, after.lines[1].chomp.length
    assert_fix before, after, RULE, :project_layout
  end
end
