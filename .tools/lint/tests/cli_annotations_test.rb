# frozen_string_literal: true

require_relative 'test_helper'

# GitHub annotations must reflect the same native diagnostics and fixes.
class CliAnnotationsTest < Minitest::Test
  include LintCliSupport

  def test_diagnostic_counts_are_independent_of_github_annotations
    [nil, 'synthetic_test'].product([[], ['--fix']]).each do |github_action, options|
      assert_annotation_counts("$values = [\n      'first',\n      'second',\n]\n$other = [1] + [2]\n", github_action,
                               options)
    end
  end

  def assert_annotation_counts(code, github_action, options)
    write_source(code, path: 'project_layout.pp')
    assert_cli_result(!options.empty?, *options, @file, env: { 'GITHUB_ACTION' => github_action })
    { 'project_layout' => 2, 'project_arrays' => 1 }.each do |check, count|
      assert_equal count, diagnostics(@output, check).length, @output
    end
    assert_equal annotation_count(github_action, options), @output.lines.grep(/\A::warning /).length, @output
    assert_annotation_source(code, options)
  end

  def assert_annotation_source(code, options)
    corrected = code.gsub('      ', '  ').sub('[1] + [2]', 'concat([1], [2])')
    assert_equal options.empty? ? code : corrected, source
  end

  def annotation_count(github_action, options)
    return 0 unless github_action

    options.empty? ? 3 : 0
  end
end
