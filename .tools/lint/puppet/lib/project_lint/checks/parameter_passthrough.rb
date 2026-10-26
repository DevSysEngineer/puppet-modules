# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/parameter_filter'
require 'project_lint/token_helpers'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Keep identity-only parameter forwarding visible at the resource declaration.
    module ParameterPassthrough
      include AstCheck
      include TokenHelpers

      def check
        @edits = []
        @source = ParameterSource.new(ast)
        @filter = ParameterFilter.new(ast, @source)
        ast.each_node(Ast::M::AttributesOperation) do |operation, parents|
          check_forwarding(operation, parents)
        end
      end

      def check_forwarding(operation, parents)
        source, filters = source_hash(operation.expr, parents)
        return unless source.is_a?(Ast::M::LiteralHash) && !source.entries.empty?

        forwarding_problems(operation, source, filters, parents).each do |node, message|
          @edits << direct_edit(operation, source, filters, parents)
          notify(:warning, message: message, line: node.line, column: node.pos, edit: @edits.length - 1)
        end
      end

      def direct_edit(operation, source, filters, parents)
        return unless filters.empty? && operation.expr.equal?(source)

        keys = source.entries.map { |entry| entry.key.value }
        return unless direct_keys?(keys, parents.last)

        { span: expression_span(operation), keys: direct_key_tokens(source) }
      end

      def direct_key_tokens(source)
        source.entries.to_h { |entry| [expression_span(entry.key).first, entry.key.value] }
      end

      def direct_keys?(keys, body)
        return false unless body.is_a?(Ast::M::ResourceBody) && keys.uniq == keys
        return false unless keys.all? { |key| key.match?(/\A[a-z_]\w*\z/) }

        (keys & body.operations.grep(Ast::M::AttributeOperation).map(&:attribute_name)).empty?
      end

      def fix(problem)
        edit = @edits.fetch(problem[:edit])
        raise PuppetLint::NoFix unless edit

        interior = direct_tokens(edit[:span])
        edit[:keys].each do |key, name|
          key.type = :NAME
          key.value = name
        end
        replace_tokens(*edit[:span], interior)
      end

      def direct_tokens(boundaries)
        first, last = boundaries
        raise PuppetLint::NoFix unless first.line == last.line && !ignored_span?(first, last)

        span = uncommented_tokens(first, last)
        opening = span.find { |token| token.type == :LBRACE }
        raise PuppetLint::NoFix unless opening && last.type == :RBRACE

        trim_direct_tokens(token_span(opening, last)[1...-1])
      end

      def uncommented_tokens(first, last)
        span = token_span(first, last)
        raise PuppetLint::NoFix if span.any? { |token| %i[COMMENT MLCOMMENT SLASH_COMMENT].include?(token.type) }

        span
      end

      def trim_direct_tokens(interior)
        interior.shift while interior.first&.type == :WHITESPACE
        interior.pop while %i[WHITESPACE COMMA].include?(interior.last&.type)
        interior
      end

      def forwarding_problems(operation, source, filters, parents)
        if filters.empty?
          return [] unless source.entries.all? { |entry| matching_pair?(entry) }

          [[operation, '[review] Pass same-named variables directly as resource attributes']]
        else
          @filter.redundant_entries(source, filters, parents).map do |entry|
            [entry.key, '[review] Pass this key directly: its source value/default matches the receiving default; ' \
                        'review effective values and other hash consumers']
          end
        end
      end

      def matching_pair?(entry)
        key = entry.key
        value = entry.value
        value = value.expr while value.is_a?(Ast::M::ParenthesizedExpression)
        (key.is_a?(Ast::M::LiteralString) || key.is_a?(Ast::M::QualifiedName)) &&
          value.is_a?(Ast::M::VariableExpression) && key.value == value.expr.value
      end

      def source_hash(node, parents)
        filters = []
        node = unfiltered(node, filters)
        node = unfiltered(@source.local_value(node, parents), filters) if node.is_a?(Ast::M::VariableExpression)
        [node, filters]
      end

      def unfiltered(node, filters)
        return unfiltered(node.expr, filters) if node.is_a?(Ast::M::ParenthesizedExpression)
        return node unless filter_call?(node)

        filters << node
        unfiltered(node.functor_expr.left_expr, filters)
      end

      def filter_call?(node)
        node.is_a?(Ast::M::CallMethodExpression) && node.arguments.empty? &&
          node.functor_expr.is_a?(Ast::M::NamedAccessExpression) && node.functor_expr.right_expr.value == 'filter'
      end
    end
    PuppetLint.new_check(:project_parameter_passthrough) { include ParameterPassthrough }
  end
end
