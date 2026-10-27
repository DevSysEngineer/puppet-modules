# frozen_string_literal: true

require_relative '../test_helper'

# Verify explicit layout fixing and native diagnostic locations.
class CliLayoutTest < Minitest::Test
  include LintCliSupport

  def test_parameter_alignment_uses_explicit_native_cli_fixing
    code = "class example (\n  String $a= 'value',\n  Optional[String] $label=undef,\n) {}\n"
    write_source(code, path: 'parameters.pp')
    arguments = ['--only-checks', 'project_parameter_alignment']
    assert_cli_failure(*arguments, @file)
    assert_equal code, source
    assert_cli_success('--fix', *arguments, @file)
    assert_includes @output, ': fixed:'
    assert_equal fixture('cli/fixtures/explicit_native_cli_fixing_expected'), source
    assert_cli_stable(fixture('cli/fixtures/explicit_native_cli_fixing_expected'), *arguments)
  end

  def test_opening_brace_spacing_fails_even_after_a_line_length_suppression
    code = fixture('cli/fixtures/a_line_length_suppression_code')
    [[], ['--fix']].each { |options| assert_brace_spacing(code, options) }
    write_source(code.sub("\n\n", "\n"), path: 'spacing.pp')
    assert_cli_success(@file)
  end

  def assert_brace_spacing(code, options)
    write_source(code, path: 'spacing.pp')
    assert_cli_result(!options.empty?, *options, @file)
    assert_equal 1, diagnostics(@output, 'project_layout').length, @output
    kind = options.empty? ? 'warning' : 'fixed'
    assert_includes @output, ":3:1: project_layout: #{kind}: Remove blank lines immediately after an opening brace"
    assert_equal options.empty? ? code : code.sub("\n\n", "\n"), source
  end

  def test_array_indentation_is_reported_and_fixed_explicitly
    code = "$command = join([\n      'printf \"%s\"',\n      'synthetic',\n    ], ' ')\n"
    [[], ['--fix']].each { |options| assert_array_indentation(code, options) }
    write_source(correct_array_indentation(code), path: 'arrays.pp')
    assert_cli_success(@file)
  end

  def correct_array_indentation(_code)
    "$command = join(['printf \"%s\"', 'synthetic'], ' ')\n"
  end

  def assert_array_indentation(code, options)
    write_source(code, path: 'arrays.pp')
    assert_cli_result(!options.empty?, *options, @file)
    assert_equal 1, diagnostics(@output, 'project_layout').length, @output
    kind = options.empty? ? 'warning' : 'fixed'
    assert_includes @output, ":1:17: project_layout: #{kind}: Use compact array layout"
    assert_equal options.empty? ? code : correct_array_indentation(code), source
  end
end
