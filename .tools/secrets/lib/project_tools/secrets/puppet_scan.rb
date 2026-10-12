# frozen_string_literal: true

require_relative 'puppet_values'
require_relative 'context'

module ProjectTools
  module Secrets
    # Inspect syntax only: never evaluate manifests, lookups, facts or functions.
    class PuppetScan
      include PuppetSyntax

      METADATA_NAME = /_(?:file(?:_shell)?|script|reader|latency|max_age(?:_correct)?|
                          warn_days|authentication_users_str|ensure)\z/ix.freeze
      def initialize(document)
        @document = document
        @values = PuppetValues.new(document)
        @literal_keys = []
      end

      def scan
        require 'puppet'
        tree = Puppet::Pops::Parser::EvaluatingParser.new.parse_string(@document.text, 'input.pp')
        tree._pcore_all_contents([]) { |node| inspect_node(node) }
      rescue LoadError
        @document.error('puppet_parser_unavailable')
      rescue StandardError, SystemStackError
        @document.error('puppet_inspection_failed')
      end

      def sensitive?(name)
        Patterns::NAME.match?(name.to_s) && !METADATA_NAME.match?(name.to_s)
      end

      def inspect_node(node)
        record_literal(node)
        case kind(node)
        when 'AssignmentExpression' then assignment(node)
        when 'AttributeOperation' then attribute(node)
        when 'Parameter' then parameter(node)
        when 'KeyedEntry' then entry(node)
        when 'CallNamedFunctionExpression' then sensitive_call(node)
        when 'CallMethodExpression' then sensitive_method(node)
        end
      end

      def record_literal(node)
        @literal_keys << node.key if kind(node) == 'KeyedEntry'
        return unless kind(node) == 'LiteralString' && @literal_keys.none? { |key| key.equal?(node) }

        @document.literals << [node.offset, node.offset + node.length, node.value, 'puppet']
      end

      def attribute(node)
        inspect_named(node.attribute_name, node.value_expr)
      end

      def entry(node)
        inspect_named(literal(node.key), node.value)
      end

      def assignment(node)
        left = node.left_expr
        inspect_named(left.expr.value, node.right_expr) if kind(left) == 'VariableExpression'
      end

      def parameter(node)
        type = node.type_expr
        typed = type && @document.text[type.offset, type.length].include?('Sensitive')
        typed ? @values.inspect_value(node.value) : inspect_named(node.name, node.value)
      end

      def inspect_named(name, node)
        return unless sensitive?(name) && node

        return if contextual_reference?(name, node)

        @values.inspect_value(node)
      end

      def contextual_reference?(name, node)
        return false unless %w[LiteralString LiteralInteger].include?(kind(node))

        Context.metadata?(name.to_s, node.value.to_s) || Context.file_reference?(name.to_s, node.value.to_s)
      end

      def sensitive_call(node)
        @values.sensitive_arguments(node) if function_name(node) == 'sensitive'
      end

      def sensitive_method(node)
        functor = node.functor_expr
        return unless kind(functor) == 'NamedAccessExpression' && functor.right_expr.value == 'new'
        return unless functor.left_expr.respond_to?(:value) && functor.left_expr.value.downcase == 'sensitive'

        @values.sensitive_arguments(node)
      end
    end
  end
end
