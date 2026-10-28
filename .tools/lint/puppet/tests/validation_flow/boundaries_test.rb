# frozen_string_literal: true

require_relative 'support'

# Preserve scope boundaries, exclusions and native reporting semantics.
class ValidationFlowBoundariesTest < Minitest::Test
  include ValidationFlowSupport

  def test_validation_stops_at_its_declaration_body
    valid = "if $valid { notice('Valid') } else { fail('Invalid') }"
    SCOPES.compact.each do |declaration|
      assert_empty findings("#{declaration} { #{valid} }; notice('Other scope')", nil)
      assert_empty findings("#{valid}; #{declaration} { notice('Other scope') }", nil)
    end
    assert_empty findings("#{valid}; class example::nested { notice('Other scope') }")
    assert_equal([:warning], findings("#{valid}; class example::nested {}; notice('Same scope')").map { |p| p[:kind] })
  end

  def test_function_bodies_and_parameter_defaults_remain_excluded
    %w[fail warning ::fail ::warning].each do |function|
      assert_empty findings("function example::helper() { #{function}('Deferred') }; notice('Other scope')", nil)
      ['class example', 'define example'].each do |declaration|
        assert_empty findings("notice('Body')", "#{declaration} (String $value = #{function}('Required'))")
      end
      assert_in_scopes("example::#{function.delete_prefix('::')}('Custom function')", [])
    end
  end

  def test_multiple_diagnostics_report_each_guard_once_and_keep_other_scopes
    invalid = "if $invalid { warning('Invalid'); ::fail('Invalid') } else { notice('Valid') }"
    assert_in_scopes(invalid, [:warning])
    assert_in_scopes("if $invalid { fail('Same') } else { fail('Same') }", [:warning])
    code = SCOPES.compact.map { |declaration| "#{declaration} { #{invalid} }" }.join("\n")
    assert_equal(Array.new(4, :warning), findings("#{code}\n#{invalid}", nil).map { |problem| problem[:kind] })
  end

  def test_native_suppressions_remain_subject_to_the_project_policy_in_every_scope
    body = "# lint:ignore:project_positive_flow\nif $invalid { fail('Invalid') }\n# lint:endignore"
    SCOPES.each do |declaration|
      code = declaration ? "#{declaration} {\n#{body}\n}\n" : "#{body}\n"
      problems, unchanged = lint_checks(code, %i[project_positive_flow project_suppressions], fix: true)
      kinds = problems.to_h { |problem| [problem[:check], problem[:kind]] }
      assert_equal({ project_positive_flow: :ignored, project_suppressions: :error }, kinds)
      assert_equal code, unchanged
    end
  end
end
