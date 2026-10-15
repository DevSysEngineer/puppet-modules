# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'duplicate_function_calls_support'

# Resolution, source ranges and evaluation paths must all support extraction.
class DuplicateFunctionBoundariesTest < Minitest::Test
  include LintTestSupport
  include DuplicateFunctionCallsSupport

  RULE = :project_duplicate_function_calls

  def test_changed_or_missing_stdlib_is_not_assumed_pure
    with_modules do |root|
      code = resource("stdlib::to_json('value')", "stdlib::to_json('value')")
      assert_clean_passes(code)
      path = File.join(root, 'stdlib/lib/puppet/functions/stdlib/to_json.rb')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "raise 'Module code must not run during linting'\n")
      assert_clean_passes(code)
    end
  end

  def test_unqualified_function_shadowing_prevents_detection
    with_modules do |root|
      path = File.join(root, 'example/lib/puppet/functions/downcase.rb')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "raise 'Module code must not run during linting'\n")
      assert_clean_passes(resource("downcase('ABC')", "downcase('ABC')"))
    end
  end

  def test_shadowed_lookup_cannot_supply_type_evidence
    with_modules do |root|
      path = File.join(root, 'functions/lookup.pp')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "function lookup($key, $type) { undef }\n")
      code = "$value = lookup('example::value', Integer)\n#{resource('String($value)', 'String($value)')}"
      assert_clean_passes(code)
    end
  end

  def test_shadowed_serialization_helper_prevents_detection
    with_modules do |root|
      ENV['PROJECT_TOOLS_MODULEPATH'] = [root, ROOT].join(File::PATH_SEPARATOR)
      path = File.join(root, 'functions/stdlib/rewrap_sensitive_data.pp')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "function stdlib::rewrap_sensitive_data($value) { undef }\n")
      assert_clean_passes(resource("stdlib::to_json('value')", "stdlib::to_json('value')"))
    end
  end

  def test_heredoc_and_multiline_first_call_are_not_rewritten
    heredoc = "@(END)\nString(42)\nEND\n"
    assert_clean_passes("$text = #{heredoc}")
    code = resource("String(\n  42\n)", 'String(42)')
    assert_preserved(code, [:warning])
  end

  def test_case_branch_fix_preserves_guard_and_other_branch
    body = "# Report the converted value.\n#{resource('Integer(42)', 'Integer(42)')}".gsub("\n", "\n    ").rstrip
    before = "case $choice {\n  'yes': {\n    #{body}\n  }\n  default: {}\n}\n"
    problems, fixed = lint(before, fix: true)
    assert_equal([:fixed], problems.map { |problem| problem[:kind] })
    assert_includes fixed, "'yes': {\n    # Report the converted value.\n    $integer_result"
    assert_includes fixed, '$integer_result = Integer(42)'
    assert_includes fixed, 'default: {}'
    Puppet::Pops::Parser::EvaluatingParser.new.parse_string(fixed)
    assert_clean_passes(fixed)
  end

  def test_parameter_defaults_inheritance_and_iterators_are_excluded_from_fix
    assert_clean_passes("class example($v = [String(42), String(42)]) {}\n")
    assert_clean_passes("[1].each |$value| { #{resource('String($value)', 'String($value)')} }")
    assert_preserved("class example inherits base {\n#{resource('String(42)', 'String(42)')}}\n", [:warning])
  end

  def test_distinct_hash_order_and_numeric_types_remain_distinct
    assert_clean_passes(resource("String({'a' => 1, 'b' => 2})", "String({'b' => 2, 'a' => 1})"))
    assert_clean_passes(resource('String(1)', 'String(1.0)'))
    assert_clean_passes(resource("split('A', /a/)", "split('A', /(?i)a/)"))
  end

  def with_modules
    previous = ENV.fetch('PROJECT_TOOLS_MODULEPATH', nil)
    Dir.mktmpdir('duplicate-functions-') do |directory|
      ENV['PROJECT_TOOLS_MODULEPATH'] = directory
      yield directory
    end
  ensure
    ENV['PROJECT_TOOLS_MODULEPATH'] = previous
  end
end
