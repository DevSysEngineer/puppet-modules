# frozen_string_literal: true

require_relative 'puppet_syntax'

module ProjectTools
  module Secrets
    # Find literal data inside sensitive expressions while preserving external references.
    class PuppetValues
      include PuppetSyntax

      def initialize(document)
        @document = document
      end

      def sensitive_arguments(node)
        node.arguments.each do |argument|
          inspect_value(argument) unless computed_reference?(argument)
        end
      end

      def computed_reference?(node)
        computed = kind(node) == 'ConcatenatedString' ||
                   (kind(node) == 'CallNamedFunctionExpression' && %w[join concat
                                                                      sprintf].include?(function_name(node)))
        computed && reference?(node)
      end

      def reference?(node)
        return true if kind(node) == 'VariableExpression'

        children(node).any? { |child| reference?(child) }
      end

      def inspect_value(node)
        return unless node

        inspect_expression(node)
      end

      def inspect_expression(node)
        case kind(node)
        when 'VariableExpression', 'LiteralUndef', 'LiteralBoolean' then nil
        when 'AccessExpression' then inspect_value(node.left_expr)
        when 'LiteralString', 'LiteralInteger', 'LiteralFloat', 'QualifiedName' then redact_literal(node)
        when 'ConcatenatedString' then interpolation(node)
        when 'CallNamedFunctionExpression', 'CallMethodExpression' then function(node)
        when 'KeyedEntry', 'SelectorEntry' then inspect_value(entry_value(node))
        else inspect_children(node)
        end
      end

      def inspect_children(node)
        children(node).each { |child| inspect_value(child) }
      end

      def entry_value(node)
        kind(node) == 'SelectorEntry' ? node.value_expr : node.value
      end

      def redact_literal(node)
        return if ['', '[REDACTED]', '!', '!!', '*'].include?(node.value.to_s)
        return @document.error('unbounded_puppet_value') unless node.length.positive?

        @document.redact(node.offset, node.offset + node.length, 'puppet_hardcoded_value',
                         "'[REDACTED]'", value: node.value.to_s)
      end

      def interpolation(node)
        # A string composed solely of references contains no hardcoded value.
        literals = node.segments.select { |part| kind(part) == 'LiteralString' && !part.value.empty? }
        return if literals.empty?

        @document.redact(node.offset, node.offset + node.length, 'puppet_hardcoded_value', "'[REDACTED]'")
      end

      def function(node)
        name = function_name(node)
        if %w[lookup hiera hiera_hash hiera_array].include?(name)
          lookup_defaults(node, name)
        elsif %w[template epp file].include?(name)
          nil
        else
          inspect_arguments(node)
        end
      end

      def inspect_arguments(node)
        node.arguments.each { |argument| inspect_value(argument) }
        inspect_value(node.lambda) if node.lambda
      end

      def lookup_defaults(node, name)
        args = node.arguments
        inspect_value(args[name == 'lookup' ? 3 : 1])
        args.each { |argument| lookup_options(argument) }
        inspect_value(node.lambda.body) if node.lambda
      end

      def lookup_options(node)
        return unless kind(node) == 'LiteralHash'

        node.entries.each do |entry|
          inspect_value(entry.value) if %w[default_value default_values_hash override].include?(literal(entry.key))
        end
      end
    end
  end
end
