# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/token_helpers'

module ProjectLint
  # Count only AST relationships that introduce a statement body.
  module ResourceIndentationScopes
    def resource_scope_depth(parents, node)
      levels = (parents + [node]).each_cons(2).map { |parent, child| resource_scope_level(parent, child) }
      levels.sum unless levels.include?(nil)
    end

    def resource_scope_level(parent, child)
      case parent
      when Ast::M::Program, Ast::M::BlockExpression, Ast::M::RelationshipExpression then 0
      when Ast::M::CaseExpression, Ast::M::CaseOption then 1
      when Ast::M::NamedDefinition, Ast::M::NodeDefinition, Ast::M::LambdaExpression
        resource_body_level(parent, child)
      when Ast::M::CallNamedFunctionExpression, Ast::M::CallMethodExpression
        0 if child.is_a?(Ast::M::LambdaExpression)
      else
        resource_branch_level(parent, child)
      end
    end

    def resource_body_level(parent, child)
      1 if parent.respond_to?(:body) && parent.body.equal?(child)
    end

    def resource_branch_level(parent, child)
      return unless parent.is_a?(Ast::M::IfExpression) || parent.is_a?(Ast::M::UnlessExpression)
      return unless parent.then_expr.equal?(child) || parent.else_expr.equal?(child)

      child.is_a?(Ast::M::IfExpression) && expression_span(child).first.type == :ELSIF ? 0 : 1
    end
  end

  # Extend the native whitespace check with positions proven by the resource AST.
  module ResourceIndentation
    include AstCheck
    include TokenHelpers
    include ResourceIndentationScopes

    RESOURCE_NODES = [Ast::M::ResourceExpression, Ast::M::ResourceDefaultsExpression,
                      Ast::M::ResourceOverrideExpression, Ast::M::CollectExpression].freeze

    def check
      super
      @resource_indents = []
      @resource_braces = resource_brace_pairs
      ast.each_node do |node, parents|
        next unless RESOURCE_NODES.any? { |type| node.is_a?(type) }

        check_resource_indentation(node, parents)
      end
    end

    def check_resource_indentation(node, parents)
      first, last = expression_span(node)
      return unless first && last

      closing = resource_closing(first, last)
      return unless closing

      depth = resource_scope_depth(parents, node)
      base = depth ? depth * 2 : manifest_lines.fetch(first.line - 1)[/\A */].length
      check_resource_indent(first, base) if depth
      check_resource_indent(closing, base)
      check_resource_contents_indent(node, first, base)
    end

    def check_resource_contents_indent(node, first, base)
      if node.is_a?(Ast::M::ResourceExpression)
        node.bodies.each { |body| check_resource_body_indent(body, first, base) }
      else
        node.operations.each { |operation| check_resource_indent(expression_span(operation).first, base + 2) }
      end
    end

    def resource_brace_pairs
      stack = []
      tokens.each_with_object({}) do |token, pairs|
        stack << token if token.type == :LBRACE
        pairs[stack.pop] = token if token.type == :RBRACE && !stack.empty?
      end
    end

    # Virtual resource positions omit the @ prefix from their AST length.
    # Match lexer braces instead of treating the AST end as a closing token.
    def resource_closing(first, last)
      finish = tokens.index(last)
      opening = token_span(first, last).find do |token|
        closing = @resource_braces[token]
        closing && tokens.index(closing) >= finish
      end
      @resource_braces[opening]
    end

    def check_resource_body_indent(body, opening, base)
      title, title_end = expression_span(body.title)
      separate_title = title.line > opening.line
      check_resource_indent(title, base + 2) if separate_title
      width = base + (separate_title || title_end.line > title.line ? 4 : 2)
      body.operations.each { |operation| check_resource_indent(expression_span(operation).first, width) }
    end

    def check_resource_indent(anchor, width)
      return unless resource_line_start?(anchor)
      return if anchor.column - 1 == width

      @resource_indents << [anchor, width]
      report_resource_indent(anchor, width, @resource_indents.length - 1)
    end

    def resource_line_start?(anchor)
      anchor && manifest_lines.fetch(anchor.line - 1)[0, anchor.column - 1].match?(/\A *\z/)
    end

    def report_resource_indent(anchor, width, index)
      existing = @problems.find { |problem| problem[:line] == anchor.line }
      if existing
        existing[:resource_indent] = index
      else
        notify(:error, message: "Resource indentation should be #{width} spaces, found #{anchor.column - 1}",
                       line: anchor.line, column: 1, resource_indent: index)
      end
    end

    def fix(problem)
      raise PuppetLint::NoFix unless problem.key?(:resource_indent)

      anchor, width = @resource_indents.fetch(problem[:resource_indent])
      raise PuppetLint::NoFix unless tokens.include?(anchor) && line_prefix(anchor).match?(/\A *\z/)

      remove_resource_indent(anchor)
      insert_whitespace(anchor, width, :INDENT)
    end

    def remove_resource_indent(anchor)
      prefix = []
      cursor = anchor.prev_token
      while cursor && %i[INDENT WHITESPACE].include?(cursor.type)
        prefix << cursor
        cursor = cursor.prev_token
      end
      prefix.each { |token| remove_token(token) }
    end
  end
end

PuppetLint.configuration.check_object.fetch(:'2sp_soft_tabs').prepend(ProjectLint::ResourceIndentation)
