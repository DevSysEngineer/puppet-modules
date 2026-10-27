# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../cli_support'
require_relative '../duplicate_function_calls_support'

# Check the native write route, shared profile and safe diagnostic payloads.
class CliDuplicateFunctionCallsTest < Minitest::Test
  include LintCliSupport
  include DuplicateFunctionCallsSupport

  CHECK = 'project_duplicate_function_calls'

  def test_nextcloud_native_fix
    assert_native_fix(nextcloud, nextcloud(shared: true), CHECK)
  end

  def test_full_profile_fix_is_stable_with_quote_and_layout_fixes
    write_source(resource('String(42)', 'String( 42 )').sub("'example'", '"example"'))
    assert_cli_failure(@file)
    assert_cli_success('--fix', @file)
    expected = "$string_result = String(42)\n#{resource('$string_result', '$string_result')}"
    assert_equal expected, source
    assert_cli_stable(expected)
  end

  def test_full_profile_preserves_a_branch_and_resource_comment
    before = "# Only configure an enabled feature.\nif true {\n  " \
             "# Report the configured value.\n  notify { 'example':\n    " \
             "message => [String(42), String(42)],\n  }\n}\n"
    write_source(before)
    assert_cli_success('--fix', @file)
    expected = before.sub('  notify', "  $string_result = String(42)\n  notify")
                     .sub('[String(42), String(42)]', '[$string_result, $string_result]')
    assert_equal expected, source
    assert_cli_stable(expected)
  end

  def test_console_exposes_only_function_and_locations
    code = resource("String('synthetic-private-value')", "String('synthetic-private-value')")
    write_source(code)
    assert_cli_failure('--only-checks', CHECK, @file)
    assert_includes @output, "#{CHECK}: warning: Repeated String()"
    refute_includes @output, 'synthetic-private-value'
    assert_equal code, source
  end

  def test_json_and_junit_expose_only_function_and_locations
    code = resource("String('synthetic-private-value')", "String('synthetic-private-value')")
    write_source(code)
    assert_cli_failure('--only-checks', CHECK, '--json', @file)
    problem = JSON.parse(@output).flatten.fetch(0)
    assert_equal CHECK, problem.fetch('check')
    assert_equal 2, problem.fetch('line')
    assert_equal 'warning', problem.fetch('kind')
    refute_includes @output, 'synthetic-private-value'
    assert_safe_junit
    assert_equal code, source
  end

  def assert_safe_junit
    report = File.join(@directory, 'lint.xml')
    output, errors, status = Open3.capture3(Gem.bin_path('lint-project', 'puppet-lint-junit'), report,
                                            stdin_data: @output)
    assert status.success?, errors
    assert_includes File.read(report), CHECK
    refute_includes File.read(report) + output + errors, 'synthetic-private-value'
  end

  def test_native_check_selection_disables_detection_and_writing
    code = resource('String(42)', 'String(42)')
    write_source(code)
    assert_cli_success('--only-checks', 'project_arrays', '--fix', @file)
    assert_empty @output
    assert_equal code, source
  end

  def test_shared_conversion_passes_the_full_profile_and_two_fix_runs
    before = shared_resource_input
    expected = "$string_result = String(42)\n\n#{before.gsub('String(42)', '$string_result')}"
    write_source(before)
    assert_cli_failure(@file)
    assert_equal before, source
    assert_cli_success('--fix', @file)
    assert_equal expected, source
    Puppet::Pops::Parser::EvaluatingParser.new.parse_string(source, @file)
    assert_cli_stable(expected)
  end

  def test_refused_group_does_not_write_a_partial_fix
    before = "if true {\n#{shared_resource_input}}\n"
    write_source(before)
    2.times { assert_cli_failure('--only-checks', CHECK, '--fix', @file) }
    assert_equal before, source
  end

  def test_native_suppression_keeps_the_file_unchanged
    before = "# lint:ignore:project_duplicate_function_calls\n#{resource('String(42)', 'String(42)')}# lint:endignore\n"
    write_source(before)
    assert_cli_success('--only-checks', CHECK, '--fix', @file)
    assert_equal before, source
  end

  def shared_resource_input
    first = resource('String(42)', 'String(42)')
    second = resource('String(42)').sub("'example'", "'other'")
    "# Report the first value.\n#{first}\n# Report the second value.\n#{second}"
  end
end
