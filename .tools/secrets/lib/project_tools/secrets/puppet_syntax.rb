# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Navigation shared by the context and value visitors for the native Puppet AST.
    module PuppetSyntax
      def kind(node)
        node.class.name.split('::').last
      end

      def children(node)
        node.to_enum(:_pcore_contents).to_a
      end

      def function_name(node)
        node.functor_expr.value.downcase if node.functor_expr.respond_to?(:value)
      end

      def literal(node)
        node.value if %w[LiteralString QualifiedName].include?(kind(node))
      end
    end
  end
end
