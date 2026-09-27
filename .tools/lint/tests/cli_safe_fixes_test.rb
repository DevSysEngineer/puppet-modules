# frozen_string_literal: true

require_relative 'test_helper'

# Verify missing native fixes through real file writes, rescans and second runs.
class CliSafeFixesTest < Minitest::Test
  include LintCliSupport

  def test_literal_and_typed_arrays_preserve_element_order_and_nested_arrays
    before = "class example (Array $items = []) {\n  $values = [1, [2]] + $items + [3]\n}\n"
    after = "class example (Array $items = []) {\n  $values = concat(concat([1, [2]], $items), [3])\n}\n"
    assert_native_fix(before, after, 'project_arrays')
  end

  def test_array_fix_preserves_upstream_quote_corrections
    before = "$values = [\"one\"] + [\"two\"]\n"
    after = "$values = concat(['one'], ['two'])\n"
    assert_native_fix(before, after, 'project_arrays', 'double_quoted_strings')
  end

  def test_unknown_array_operand_and_multiline_expression_stay_for_review
    ["$values = [1] + $unknown\n", "$values = [\n  1,\n] + [2]\n"].each do |code|
      assert_review_source(code, 'project_arrays', options: ['--only-checks=project_arrays'])
    end
  end

  def test_parameter_order_preserves_literal_defaults_and_existing_quotes
    before = "class example (\n  String $zulu = \"z\",\n  String $alpha = \"a\",\n) {}\n"
    after = "class example (\n  String $alpha = 'a',\n  String $zulu  = 'z',\n) {}\n"
    assert_native_fix(before, after, 'project_parameter_order', 'double_quoted_strings', 'project_parameter_alignment')
  end

  def test_parameter_defaults_with_calls_or_dependencies_and_comments_stay_unchanged
    ["class example (String $z = lookup('value'), String $a = 'a') {}\n",
     "class example (String $z = 'z', String $a = $z) {}\n",
     "class example (\n  String $z = 'z', # Keep this context.\n  String $a = 'a',\n) {}\n"].each do |code|
      write_source(code)
      assert_cli_failure('--fix', '--only-checks=project_parameter_order', @file)
      assert_equal code, source
    end
  end

  def documentation(parameters)
    <<~PUPPET
      # @summary Demonstrates safe parameter ordering.
      #
      # @example Declare this class
      #   include example
      #
      #{parameters}#
      # @api public
    PUPPET
  end

  def test_parameter_documentation_moves_existing_descriptions_with_their_tags
    before = documentation("# @param zulu\n#   Describes zulu.\n# @param alpha Describes alpha.\n")
    after = documentation("# @param alpha Describes alpha.\n# @param zulu\n#   Describes zulu.\n")
    declaration = "class example (String $alpha, String $zulu) {}\n"
    assert_native_fix(before + declaration, after + declaration, 'project_documentation')
  end

  def test_parameter_and_documentation_order_are_fixed_together
    before = documentation("# @param zulu Describes zulu.\n# @param alpha Describes alpha.\n")
    after = documentation("# @param alpha Describes alpha.\n# @param zulu Describes zulu.\n")
    assert_native_fix("#{before}class example (String $zulu, String $alpha) {}\n",
                      "#{after}class example (String $alpha, String $zulu) {}\n",
                      'project_parameter_order', 'project_documentation')
  end

  def test_missing_documentation_is_not_invented_or_removed
    code = "#{documentation("# @param zulu Describes zulu.\n")}class example (String $alpha, String $zulu) {}\n"
    assert_review_source(code, 'project_documentation', options: ['--only-checks=project_documentation'])
  end

  def test_inline_identity_hash_is_expanded_without_changing_values
    after = "example::task { 'example': alpha => $alpha, zulu => $zulu }\n"
    ["'alpha'", '"al\u0070ha"'].each do |key|
      before = "example::task { 'example': * => { #{key} => $alpha, 'zulu' => $zulu } }\n"
      assert_native_fix(before, after, 'project_parameter_passthrough')
    end
  end

  def test_shared_hash_and_conflicting_attributes_are_preserved
    ["$settings = { 'alpha' => $alpha }\nexample::task { 'example': * => $settings }\n",
     "example::task { 'example': alpha => 'explicit', * => { 'alpha' => $alpha } }\n"].each do |code|
      assert_review_source(code, 'project_parameter_passthrough',
                           options: ['--only-checks=project_parameter_passthrough'])
    end
  end

  def test_native_suppression_prevents_new_fixes
    examples = { 'project_arrays' => '$values = [1] + [2]',
                 'project_parameter_order' => 'class example (String $zulu, String $alpha) {}',
                 'project_parameter_passthrough' => "example::task { 'example': * => { 'alpha' => $alpha } }" }
    examples.each do |check, code|
      source = "# lint:ignore:#{check}\n#{code}\n# lint:endignore\n"
      write_source(source)
      assert_cli_success('--fix', "--only-checks=#{check}", @file)
      assert_equal source, self.source
    end
  end

  def test_literal_relationship_direction_uses_the_existing_native_check
    assert_native_fix("File['later'] <- File['earlier']\n", "File['earlier'] -> File['later']\n",
                      'right_to_left_relationship')
    assert_review_source("File[$later] <- File['earlier']\n", 'right_to_left_relationship',
                         options: ['--only-checks=right_to_left_relationship'])
  end

  def test_full_profile_parameter_and_documentation_fixes_are_stable
    code = documentation("# @param zulu Describes zulu.\n# @param alpha Describes alpha.\n")
    code += "class example (\n  String $zulu = 'z',\n  String $alpha = 'a',\n) {}\n"
    write_source(code, path: 'example/manifests/init.pp')
    assert_cli_success('--fix', @file)
    assert_cli_stable(source)
  end

  def test_full_profile_identity_hash_fix_is_stable
    write_source("example::task { 'example': * => { 'alpha' => $alpha, 'zulu' => $zulu } }\n")
    assert_cli_success('--fix', @file)
    assert_cli_stable(source)
  end
end
