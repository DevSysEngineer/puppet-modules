# frozen_string_literal: true

require_relative 'support'

# Verify terminal validation structure and fallback branches through native lint findings.
class ValidationFlowStructureTest < Minitest::Test
  include ValidationFlowSupport

  TRAILING_IMPLEMENTATIONS = [
    "if $valid { notify { 'synthetic': } } else { fail('Invalid') }; $later = true",
    "if $outer { if $valid { notify { 'synthetic': } } else { fail('Invalid') }; notice('Later') }",
    "if $outer { if $valid { notify { 'synthetic': } } else { fail('Invalid') } }; notify { 'later': }",
    "if $first { if $second { if $valid { notice('Valid') } else { fail('Invalid') } } }; include later",
    "$value = if $valid { 'valid' } else { fail('Invalid') }; notice($value)",
    "[1].each |$value| { if $value > 0 { notice('Valid') } else { fail('Invalid') } }; notice('Later')",
    "[1].each |$value| { if $value > 0 { notice('Valid') } else { fail('Invalid') }; notice('Later') }",
    "case $state { 'active': { notice('Active') } default: { fail('Invalid') } }; notice('Later')",
    "case $state { 'active': { if $valid { notice('Valid') } else { fail('Invalid') } } " \
    "default: { notice('Inactive') } }; notice('Later')",
    "if $outer { case $state { 'active': { notice('Active') } default: { fail('Invalid') } } }; notice('Later')",
    "[1].each |$value| { case $value { 1: { notice('Valid') } default: { fail('Invalid') } } }; notice('Later')"
  ].freeze

  def test_nested_validation_else_arms_are_alternatives_not_trailing_implementation
    body = fixture('validation_flow/fixtures/alternatives_not_trailing_implementation_body')
    %w[fail warning ::fail ::warning].each do |function|
      assert_in_scopes(body.gsub('fail(', "#{function}("), [])
    end
    assert_in_scopes(body.gsub("\n", "\r\n"), [])
  end

  def test_trailing_code_is_detected_at_every_enclosing_statement_block
    TRAILING_IMPLEMENTATIONS.each do |body|
      %w[fail warning ::fail ::warning].each do |function|
        assert_in_scopes(body.gsub('fail(', "#{function}("), [:warning], message: 'no implementation may follow')
      end
    end
  end

  def test_direct_and_nonfinal_diagnostics_require_a_fallback_even_for_equal_size_branches
    %w[fail warning ::fail ::warning].each do |function|
      diagnostic_branches(function).each { |body| assert_in_scopes(body, [:warning], message: 'final else') }
      assert_in_scopes("if $valid { notice('Valid') } else { #{function}('Invalid') }", [])
      assert_in_scopes("case $state { 'active': { notice('Active') } default: { #{function}('Invalid') } }", [])
    end
  end

  def test_sequential_validations_must_be_nested
    body = "if $first { notice('First') } else { fail('First missing') }; if $second { " \
           "notice('Second') } else { fail('Second missing') }"
    assert_in_scopes(body, [:warning], message: 'no implementation may follow')
  end

  def test_multiple_final_diagnostics_and_message_preparation_keep_the_fallback_last
    body = fixture('validation_flow/fixtures/keep_the_fallback_last_body')
    assert_in_scopes(body, [])
    assert_in_scopes(body.sub('} else {', "} elsif $alternative {\n  notice('Alternative')\n} else {"), [])
    ["notice('Regular code')", '$unrelated = true', "notify { 'synthetic': }"].each do |extra|
      assert_in_scopes(body.sub('  warning($message)', "  #{extra}\n  warning($message)"), [:warning])
      assert_in_scopes(body.sub("  fail('Cannot proceed')", "  fail('Cannot proceed')\n  #{extra}"), [:warning])
    end
  end

  def test_case_defaults_and_elsif_arms_follow_the_same_terminal_structure
    assert_case_defaults
    assert_in_scopes("if $first { notice('First') } elsif $second { notice('Second') } else { fail('Neither') }", [])
    invalid = "if $first { notice('First') } elsif $invalid { fail('Invalid') } else { fail('Neither') }"
    assert_in_scopes(invalid, [:warning])
    assert_in_scopes("unless $invalid { notice('Valid') } else { fail('Invalid') }", [])
  end

  def test_outer_alternative_with_implementation_may_follow_a_nested_validation
    assert_in_scopes("if $active { if $valid { notify { 'synthetic': } } else { fail('Invalid') " \
                     "} } else { notice('Inactive') }", [])
    assert_in_scopes("case $state { 'active': { if $valid { notify { 'synthetic': } } else { " \
                     "fail('Invalid') } } default: { notice('Inactive') } }", [])
    assert_in_scopes("if $active { [1].each |$value| { case $value { 1: { notice('Valid') } " \
                     "default: { fail('Invalid') } } } } else { notice('Inactive') }", [])
  end

  def test_declaration_boundaries_defaults_and_non_diagnostic_text_do_not_trigger_the_rule
    body = fixture('validation_flow/fixtures/not_trigger_the_rule_body')
    assert_in_scopes(body, [])
    assert_empty findings(fixture('validation_flow/fixtures/not_trigger_the_rule_sample'))
    assert_empty findings("if $valid { notice('Valid') } else { fail('Invalid') }",
                          "define example (String $value = fail('Required'))")
    assert_empty findings(fixture('validation_flow/fixtures/not_trigger_the_rule_sample2'))
  end

  def test_generic_branch_sizing_still_applies_without_a_diagnostic_fallback
    assert_in_scopes("if $short { notice('Short') } else { $one = 1; $two = 2 }", [:warning])
    assert_in_scopes("if $long { $one = 1; $two = 2 } else { notice('Short') }", [])
  end

  def assert_case_defaults
    assert_in_scopes("case $state { 'active': { notice('Active') } default: { fail('Invalid') } }", [])
    following = "case $state { 'active': { notice('Active') } default: { fail('Invalid') } }; notice('Later')"
    assert_in_scopes(following, [:warning])
    assert_in_scopes("case $state { 'invalid': { fail('Invalid') } default: { notice('Valid') } }", [:warning])
    assert_in_scopes("case $state { default: { fail('Invalid') } 'active': { notice('Active') } }", [:warning])
  end

  def diagnostic_branches(function)
    [
      "#{function}('Invalid'); notice('Later')",
      "#{function}('Invalid')",
      "if $invalid { #{function}('Invalid') }; notice('Later')",
      "if $invalid { #{function}('Invalid') } else { notice('Valid') }",
      "if $invalid { #{function}('Invalid') } else { $one = 1; $two = 2 }"
    ]
  end
end
