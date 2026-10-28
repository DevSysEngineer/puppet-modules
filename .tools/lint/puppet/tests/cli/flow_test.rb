# frozen_string_literal: true

require_relative '../test_helper'

# Preserve evaluation order and backend decisions while reporting structural review findings.
class CliFlowTest < Minitest::Test
  include LintCliSupport

  def test_branch_order_fails_without_rewriting_conditions_with_fix
    assert_review_source(fixture('cli/fixtures/rewriting_conditions_with_fix_code'), 'project_positive_flow')
  end

  def test_validation_structure_checks_enclosing_blocks_without_rewriting_them
    code = fixture('cli/fixtures/blocks_without_rewriting_them_code')
    options = ['--only-checks', 'project_positive_flow']
    assert_review_source(code, 'project_positive_flow', count: 2, options: options)
    assert_includes @output, 'no implementation may follow'
    corrected = code.sub("  notify { 'outside-validation': }\n", '')
    write_source(corrected.sub("      notice('Valid')",
                               "      notice('Valid')\n      notify { 'inside-validation': }"))
    assert_cli_success(*options, @file)
  end

  def test_monitoring_backend_check_does_not_rewrite_backend_conditions_with_fix
    code = fixture('cli/fixtures/backend_conditions_with_fix_code')
    assert_review_source(code, 'project_monitoring_backend')
    write_source(code.sub("== 'synthetic_backend'", "!= 'none'"))
    assert_cli_success(@file)
  end

  def test_node_validation_fails_with_the_project_profile
    code = fixture('cli/fixtures/node_validation_invalid')
    write_source(code)
    capture_cli(@file)
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_equal 1, diagnostics(@output, 'project_positive_flow').length, @output
    assert_includes @output, 'project_positive_flow: warning: Put validation'
    assert_equal code, source
  end

  def test_validation_scopes_preserve_source_and_exit_status_with_fix
    ['class example', 'define example', "node 'example.test'", nil].each do |declaration|
      %w[fail warning ::fail ::warning].each do |function|
        invalid = "if !$supported { #{function}('Unsupported') }; notice('Outside')"
        valid = "if $supported { notice('Inside') } else { #{function}('Unsupported') }"
        assert_validation_pair(declaration, invalid, valid)
      end
    end
  end

  def assert_validation_pair(declaration, invalid, valid)
    options = ['--only-checks', 'project_positive_flow']
    code = declaration ? "#{declaration} { #{invalid} }\n" : "#{invalid}\n"
    assert_review_source(code, 'project_positive_flow', options: options)
    assert_equal 1, @status.exitstatus
    corrected = declaration ? "#{declaration} { #{valid} }\n" : "#{valid}\n"
    write_source(corrected)
    assert_cli_stable(corrected, *options)
  end

  def test_class_check_reuse_does_not_change_evaluation_order_with_fix
    ["$enabled = defined(Class['synthetic']); notice($enabled)",
     "notice(defined(Class['synthetic'])); include synthetic; notice(defined(Class['synthetic']))"].each do |body|
      assert_review_source("class example { #{body} }\n", 'project_class_check_reuse',
                           options: ['--only-checks', 'project_class_check_reuse'])
    end
  end
end
