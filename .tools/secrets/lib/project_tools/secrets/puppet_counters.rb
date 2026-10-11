# frozen_string_literal: true

require_relative 'puppet_syntax'

module ProjectTools
  module Secrets
    # Identify individual numeric literals used as counters, never whole safe lambdas.
    class PuppetCounters
      include PuppetSyntax

      def literals(call)
        return [] unless call.lambda && call.lambda.parameters.size == 2

        @parameters = call.lambda.parameters.map(&:name)
        case method_name(call)
        when 'reduce' then reduce_literals(call)
        when 'filter' then filter_literals(call.lambda.body)
        else []
        end
      end

      def method_name(call)
        functor = call.functor_expr
        kind(functor) == 'NamedAccessExpression' ? functor.right_expr.value : function_name(call)
      end

      def reduce_literals(call)
        initial = call.arguments.last
        return [] unless kind(initial) == 'LiteralHash' && initial.entries.empty?

        body = call.lambda.body
        statements = kind(body) == 'BlockExpression' ? body.statements : [body]
        statements.flat_map { |statement| counter_branch(statement) }
      end

      def counter_branch(node)
        return [] unless kind(node) == 'IfExpression'

        key = missing_counter_key(node.test)
        first = counter_value(node.then_expr, key)
        increment = counter_value(node.else_expr, key)
        return [] unless one?(first) && addition?(increment) &&
                         counter_key(increment.left_expr) == key && one?(increment.right_expr)

        [first, increment.right_expr]
      end

      def missing_counter_key(node)
        node = unwrap(node)
        return unless kind(node) == 'ComparisonExpression' && node.operator == '==' &&
                      kind(node.right_expr) == 'LiteralUndef'

        counter_key(node.left_expr)
      end

      def addition?(node)
        kind(node) == 'ArithmeticExpression' && node.operator == '+'
      end

      def counter_key(node)
        return unless kind(node) == 'AccessExpression' && variable(node.left_expr) == @parameters.first &&
                      node.keys.size == 1

        variable(node.keys.first)
      end

      def counter_value(node, key)
        node = unwrap(node)
        return unless key && addition?(node) &&
                      variable(node.left_expr) == @parameters.first && kind(node.right_expr) == 'LiteralHash'

        node.right_expr.entries.find { |entry| variable(entry.key) == key }&.value
      end

      def filter_literals(node)
        node = unwrap(node)
        return [] unless kind(node) == 'ComparisonExpression' && %w[> >= < <=].include?(node.operator) &&
                         variable(node.left_expr) == @parameters.last && kind(node.right_expr) == 'LiteralInteger'

        [node.right_expr]
      end

      def unwrap(node)
        node = node.expr while kind(node) == 'ParenthesizedExpression'
        kind(node) == 'BlockExpression' ? unwrap(node.statements.last) : node
      end

      def variable(node)
        node.expr.value if kind(node) == 'VariableExpression'
      end

      def one?(node)
        kind(node) == 'LiteralInteger' && node.value == 1
      end
    end
  end
end
