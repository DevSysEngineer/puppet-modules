# frozen_string_literal: true

require_relative 'test_helper'

# Simulate changed evaluator behavior using only the already selected parser runtime.
class LiteralEvaluatorTest < Minitest::Test
  def test_current_runtime_preserves_literal_values_and_rejects_unknown_expressions
    evaluator = ProjectLint::LiteralEvaluator.build
    assert_instance_of Puppet::Pops::Evaluator::JsonStrictLiteralEvaluator, evaluator
  end

  def test_missing_evaluator_api_is_an_error
    error = assert_raises(ProjectTools::Shared::PuppetRuntime::Error) do
      ProjectLint::LiteralEvaluator.verify(Object.new)
    end
    assert_includes error.message, 'incompatible'
  end

  def test_changed_literal_behavior_is_an_error
    evaluator = Object.new
    evaluator.define_singleton_method(:literal) { |*| throw :not_literal }
    error = assert_raises(ProjectTools::Shared::PuppetRuntime::Error) do
      ProjectLint::LiteralEvaluator.verify(evaluator)
    end
    assert_includes error.message, 'behavior probe'
  end

  def test_unknown_expression_must_signal_that_it_is_not_literal
    evaluator = ProjectLint::LiteralEvaluator.build
    original = evaluator.method(:literal)
    evaluator.define_singleton_method(:literal) do |node|
      node.is_a?(Puppet::Pops::Model::VariableExpression) ? nil : original.call(node)
    end
    assert_raises(ProjectTools::Shared::PuppetRuntime::Error) { ProjectLint::LiteralEvaluator.verify(evaluator) }
  end
end
