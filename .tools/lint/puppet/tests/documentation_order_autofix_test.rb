# frozen_string_literal: true

require_relative 'test_helper'

# Layout edits must remain attached to the matching parameter after reordering.
class DocumentationOrderAutofixTest < Minitest::Test
  include LintCliSupport

  def test_wrapped_parameter_descriptions_and_separators_move_together
    description = 'Preserve every word in this deliberately long parameter description. ' * 40
    write_source(<<~PUPPET, path: 'example/manifests/init.pp')
      # @summary Demonstrates documentation ordering.
      #
      # @example Declare this class
      #   include example
      #
      # @param zulu #{description.strip}
      # @param alpha Describes alpha.
      #
      # @api public
      class example (
        String $zulu = 'z',
        String $alpha = 'a',
      ) {}
    PUPPET
    assert_cli_failure('--fix', @file)
    assert_preserved_description(description)
    assert_cli_stable(source)
  end

  def assert_preserved_description(description)
    assert_equal 1, diagnostics(@output, '140chars').length
    fixed = source
    assert_operator fixed.index('@param alpha'), :<, fixed.index('@param zulu')
    continuation = fixed[/# @param zulu\n((?:#   .*\n)+)/, 1]
    assert_equal description.strip, continuation.lines.map { |line| line.strip.delete_prefix('#   ') }.join(' ')
  end

  def test_suppressed_parameter_tags_are_not_reordered
    code = <<~PUPPET
      # @summary Demonstrates documentation ordering.
      # @example Declare this class
      #   include example
      # lint:ignore:project_documentation
      # @param zulu Describes zulu.
      # @param alpha Describes alpha.
      # lint:endignore
      # @api public
      class example (String $alpha, String $zulu) {}
    PUPPET
    assert_review_source(code, 'project_documentation', options: ['--only-checks=project_documentation'])
  end
end
