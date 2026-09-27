# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/token_helpers'
require 'project_lint/parameter_source'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Check declaration order and explain necessary deviations from alphabetical order.
    module ParameterOrder
      # Order parameter defaults by their local dependency graph.
      class ParameterDependencies
        def initialize(ast, parameters)
          @ast = ast
          @parameters = parameters
          @by_name = parameters.to_h { |parameter| [parameter.name, parameter] }
          @ordered = []
          @visiting = []
        end

        def ordered
          @parameters.sort_by { |parameter| [@ast.optional?(parameter) ? 1 : 0, parameter.name] }.each do |parameter|
            visit(parameter)
          end
          @ordered
        end

        def visit(parameter)
          return if @ordered.include?(parameter)
          raise 'Cyclic parameter defaults' if @visiting.include?(parameter)

          @visiting << parameter
          dependencies(parameter).each { |name| visit(@by_name.fetch(name)) }
          @visiting.pop
          @ordered << parameter
        end

        def dependencies(parameter)
          @ast.references(parameter.value).select { |name| @by_name.key?(name) }.sort
        end
      end

      include AstCheck
      include TokenHelpers

      def check
        @orders = []
        ast.declarations.each do |declaration|
          expected = ParameterDependencies.new(ast, declaration.parameters).ordered
          check_order(declaration, expected)
          check_forward_references(declaration.parameters)
          check_dependency_comments(declaration.parameters, expected)
        end
      end

      def check_order(declaration, expected)
        return if declaration.parameters == expected

        @orders << { declaration: declaration, expected: expected, spans: parameter_spans(declaration.parameters) }
        notify(:warning,
               message: 'Put mandatory parameters first, then optional parameters; sort each group alphabetically ' \
                        'subject to local default dependencies',
               line: declaration.line, column: declaration.pos, edit: @orders.length - 1)
      end

      def parameter_spans(parameters)
        parameters.map do |parameter|
          first = parameter.type_expr || parameter
          last = parameter.value || parameter
          [expression_span(first).first, expression_span(last).last]
        end
      end

      def fix(problem)
        raise PuppetLint::NoFix unless problem.key?(:edit)

        order = @orders.fetch(problem[:edit])
        spans = order[:spans]
        validate_parameter_spans(spans)
        # Leave separators and indentation in their slots; move live tokens, including upstream quote fixes.
        replacement = reordered_tokens(spans, parameter_indices(order))
        replace_tokens(spans.first.first, spans.last.last, replacement)
      end

      def parameter_indices(order)
        parameters = order[:declaration].parameters
        raise PuppetLint::NoFix unless parameters.all? { |parameter| independent_parameter?(parameter) }

        order[:expected].map { |parameter| parameters.index(parameter) }
      end

      def independent_parameter?(parameter)
        source = ParameterSource.new(ast)
        return false if parameter.value && !source.literal(parameter.value)

        type = parameter.type_expr
        return true unless type

        ([type] + ast.descendants(type)).none? do |node|
          node.is_a?(Ast::M::VariableExpression) || node.is_a?(Ast::M::CallExpression)
        end
      end

      def validate_parameter_spans(spans)
        first = spans.first.first
        last = spans.last.last
        raise PuppetLint::NoFix if ignored_span?(first, last)
        raise PuppetLint::NoFix if token_span(first, last).any? do |token|
          %i[COMMENT MLCOMMENT SLASH_COMMENT HEREDOC_OPEN].include?(token.type)
        end
        raise PuppetLint::NoFix unless spans.all? { |start, finish| start.line == finish.line }
      end

      def check_forward_references(parameters)
        positions = parameters.each_with_index.to_h { |parameter, index| [parameter.name, index] }
        parameters.each do |parameter|
          # Report each forward dependency separately.
          forward_dependencies(parameter, positions).each do |_dependency|
            issue(parameter, 'A local default refers to a parameter that must be declared earlier')
          end
        end
      end

      def forward_dependencies(parameter, positions)
        ast.references(parameter.value).select do |dependency|
          positions.key?(dependency) && positions[dependency] >= positions.fetch(parameter.name)
        end
      end

      def check_dependency_comments(parameters, expected)
        ordinary = parameters.sort_by { |parameter| [ast.optional?(parameter) ? 1 : 0, parameter.name] }
        expected.each do |parameter|
          next unless expected.index(parameter) < ordinary.index(parameter)

          dependents = default_dependents(parameters, parameter)
          check_comment(parameter, dependents) unless dependents.empty?
        end
      end

      def default_dependents(parameters, parameter)
        parameters.select { |other| ast.references(other.value).include?(parameter.name) }
      end

      def check_comment(parameter, dependents)
        comments = tokens.select { |token| token.type == :COMMENT && token.line == parameter.line }
        return if comments.any? do |comment|
          dependents.any? do |dependent|
            comment.value.include?("$#{dependent.name}")
          end
        end

        issue(parameter,
              'Explain the necessary default dependency in a trailing comment naming the dependent parameter')
      end
    end
    PuppetLint.new_check(:project_parameter_order) { include ParameterOrder }
  end
end
