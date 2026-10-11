# frozen_string_literal: true

require_relative 'puppet_values'

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
        case kind(node)
        when 'AssignmentExpression' then assignment(node)
        when 'AttributeOperation' then attribute(node)
        when 'Parameter' then parameter(node)
        when 'KeyedEntry' then entry(node)
        when 'CallNamedFunctionExpression' then sensitive_call(node)
        when 'CallMethodExpression' then sensitive_method(node)
        end
      end

      def attribute(node)
        @values.inspect_value(node.value_expr) if sensitive?(node.attribute_name)
      end

      def entry(node)
        @values.inspect_value(node.value) if sensitive?(literal(node.key))
      end

      def assignment(node)
        left = node.left_expr
        @values.inspect_value(node.right_expr) if kind(left) == 'VariableExpression' && sensitive?(left.expr.value)
      end

      def parameter(node)
        type = node.type_expr
        typed = type && @document.text[type.offset, type.length].include?('Sensitive')
        @values.inspect_value(node.value) if sensitive?(node.name) || typed
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
