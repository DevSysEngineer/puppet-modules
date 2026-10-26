# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/token_helpers'

module ProjectLint
  # The native YAML scan has no Puppet token stream to render during a fix run.
  module ManifestFixOutput
    def manifest
      return '' if File.extname(PuppetLint::Data.path).match?(/\.ya?ml\z/i)

      super
    end
  end

  # Native YAML diagnostics have no rewrite tokens; unmappable facts must not lose hash keys.
  module LegacyFactFixGuard
    def fix(problem)
      raise PuppetLint::NoFix unless problem[:token] && problem[:fact_name]
      raise PuppetLint::NoFix if UNCONVERTIBLE_FACTS.include?(problem[:fact_name])

      super
    end
  end

  # Upstream 5.1 inserts before the attribute name when no whitespace token exists.
  module MissingArrowSpaceFix
    def fix(problem)
      token = problem[:token]
      return super if token.type == :WHITESPACE

      raise PuppetLint::NoFix if formatting_tokens.include?(token.type) || token.next_token&.type != :FARROW

      add_token(tokens.index(token) + 1, PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', token.line, token.column))
    end
  end

  # Extend the existing native diagnostic, retaining its configuration and suppressions.
  module ReferenceDirectionFix
    include AstCheck
    include TokenHelpers

    def check
      super
      @directions = {}
      ast.each_node(Ast::M::RelationshipExpression) do |node, parents|
        next unless literal_relationship?(node, parents)

        @directions[[node.line, node.pos]] = [expression_span(node.left_expr), expression_span(node.right_expr)]
      end
    end

    def literal_relationship?(node, parents)
      node.operator == '<-' && standalone_relationship?(parents.last) &&
        [node.left_expr, node.right_expr].all? { |operand| literal_reference?(operand) }
    end

    def standalone_relationship?(parent)
      parent.is_a?(Ast::M::Program) || parent.is_a?(Ast::M::BlockExpression)
    end

    def literal_reference?(node)
      node.is_a?(Ast::M::AccessExpression) && node.left_expr.is_a?(Ast::M::QualifiedReference) &&
        node.keys.all?(Ast::M::LiteralString)
    end

    def fix(problem)
      spans = @directions[[problem[:line], problem[:column]]]
      raise PuppetLint::NoFix unless spans

      span = direction_tokens(spans)
      arrow = span.find { |token| token.type == :OUT_EDGE }
      raise PuppetLint::NoFix unless arrow

      replacement = reordered_tokens(spans, [1, 0])
      arrow.type = :IN_EDGE
      arrow.value = '->'
      replace_tokens(span.first, span.last, replacement)
    end

    def direction_tokens(spans)
      first = spans.first.first
      last = spans.last.last
      raise PuppetLint::NoFix unless first.line == last.line && !ignored_span?(first, last)

      span = token_span(first, last)
      raise PuppetLint::NoFix if span.any? { |token| %i[COMMENT MLCOMMENT SLASH_COMMENT].include?(token.type) }

      span
    end
  end
end

PuppetLint.configuration.check_object.fetch(:right_to_left_relationship).prepend(ProjectLint::ReferenceDirectionFix)
PuppetLint.configuration.check_object.fetch(:space_before_arrow).prepend(ProjectLint::MissingArrowSpaceFix)
PuppetLint.configuration.check_object.fetch(:legacy_facts).prepend(ProjectLint::LegacyFactFixGuard)
PuppetLint::Checks.prepend(ProjectLint::ManifestFixOutput)
