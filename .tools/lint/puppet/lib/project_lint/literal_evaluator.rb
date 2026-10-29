# frozen_string_literal: true

require 'project_tools/shared/puppet_runtime'

module ProjectLint
  # Verify literal values and the unknown-expression signal before trusting static data.
  module LiteralEvaluator
    module_function

    def build
      ProjectTools::Shared::PuppetRuntime.load!('puppet/pops/evaluator/json_strict_literal_evaluator')
      verify(Puppet::Pops::Evaluator::JsonStrictLiteralEvaluator.new)
    rescue NameError
      raise ProjectTools::Shared::PuppetRuntime::Error, 'Puppet literal evaluator interface is unavailable.'
    end

    def verify(evaluator)
      assignment = probe_assignment
      return evaluator if literal_values?(evaluator, assignment.right_expr) && unknown?(evaluator, assignment.left_expr)

      raise ProjectTools::Shared::PuppetRuntime::Error, 'Puppet literal evaluator failed the behavior probe.'
    rescue ProjectTools::Shared::PuppetRuntime::Error
      raise
    rescue StandardError
      raise ProjectTools::Shared::PuppetRuntime::Error, 'Puppet literal evaluator interface is incompatible.'
    end

    def probe_assignment
      parser = ProjectTools::Shared::PuppetRuntime.parser
      tree = parser.parse_string("$probe = ['ok', 2, true, false, undef, [1], {'key' => 'value'}]", 'literal_probe.pp')
      nodes = []
      tree._pcore_all_contents([]) { |node| nodes << node }
      nodes.find { |node| node.is_a?(Puppet::Pops::Model::AssignmentExpression) }
    end

    def literal_values?(evaluator, node)
      values = catch(:not_literal) { [evaluator.literal(node)] }
      expected = [['ok', 2, true, false, nil, [1], { 'key' => 'value' }]]
      values == expected
    end

    def unknown?(evaluator, node)
      catch(:not_literal) do
        evaluator.literal(node)
        :accepted
      end.nil?
    end
  end
end
