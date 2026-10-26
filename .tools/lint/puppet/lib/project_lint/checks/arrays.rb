# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/token_helpers'
require 'project_lint/parameter_source'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Recognize array addition from local assignments and declared parameter types.
    module Arrays
      include AstCheck
      include TokenHelpers

      def array?(node, scope, seen = [])
        return true if node.is_a?(Ast::M::LiteralList)
        return false unless node.is_a?(Ast::M::VariableExpression)

        name = node.expr.value
        return false if seen.include?(name)

        array_source?(name, scope, seen)
      end

      def array_source?(name, scope, seen)
        ast.nodes.any? do |candidate, parents|
          next false unless ast.scope_of(parents).equal?(scope)

          array_parameter?(candidate, name) || array_assignment?(candidate, name, scope, seen)
        end
      end

      def array_parameter?(candidate, name)
        candidate.is_a?(Ast::M::Parameter) && candidate.name == name &&
          ast.named_type?(candidate.type_expr, 'Array')
      end

      def array_assignment?(candidate, name, scope, seen)
        return false unless candidate.is_a?(Ast::M::AssignmentExpression)

        left = candidate.left_expr
        left.is_a?(Ast::M::VariableExpression) && left.expr.value == name &&
          array?(candidate.right_expr, scope, seen + [name])
      end

      def check
        @edits = []
        @source = ParameterSource.new(ast)
        ast.each_node(Ast::M::ArithmeticExpression) do |node, parents|
          next unless node.operator == '+'

          scope = ast.scope_of(parents)
          next unless array?(node.left_expr, scope) || array?(node.right_expr, scope)

          report_array(node, parents)
        end
      end

      def report_array(node, parents)
        safe = known_array?(node.left_expr, parents) && known_array?(node.right_expr, parents)
        operator = operator_token(node)
        @edits << { span: expression_span(node), operator: operator, safe: safe }
        notify(:warning, message: 'Combine arrays with concat(...) while preserving element order',
                         line: node.line, column: node.pos, edit: @edits.length - 1)
      end

      def operator_token(node)
        tokens.find { |token| token.line == node.line && token.column == node.pos }
      end

      def known_array?(node, parents, seen = [])
        node = @source.unwrap(node)
        return false if seen.any? { |previous| previous.equal?(node) }
        return true if node.is_a?(Ast::M::LiteralList)

        if node.is_a?(Ast::M::ArithmeticExpression) && node.operator == '+'
          return known_array?(node.left_expr, parents, seen) && known_array?(node.right_expr, parents, seen)
        end

        known_array_variable?(node, parents, seen)
      end

      def known_array_variable?(node, parents, seen)
        return false unless node.is_a?(Ast::M::VariableExpression)

        value = @source.local_value(node, parents)
        return known_array?(value, parents, seen + [node]) if value

        scope = ast.scope_of(parents)
        scope.respond_to?(:parameters) && scope.parameters.any? do |parameter|
          array_parameter?(parameter, node.expr.value)
        end
      end

      def fix(problem)
        edit = @edits.fetch(problem[:edit])
        first, last = edit[:span]
        raise PuppetLint::NoFix unless edit[:safe] && first && last && first.line == last.line
        raise PuppetLint::NoFix if ignored_span?(first, last)

        operator = edit[:operator]
        raise PuppetLint::NoFix unless tokens.include?(operator)

        replace_addition(operator, first, last)
      end

      def replace_addition(operator, first, last)
        before = operator.prev_token
        remove_token(before) if before.type == :WHITESPACE
        operator.type = :COMMA
        operator.value = ','
        insert_tokens_after(last, PuppetLint::Lexer.new.tokenise(')'))
        index = tokens.index(first)
        PuppetLint::Lexer.new.tokenise('concat(').each_with_index { |token, offset| add_token(index + offset, token) }
      end
    end
    PuppetLint.new_check(:project_arrays) { include Arrays }
  end
end
