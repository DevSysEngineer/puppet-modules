# frozen_string_literal: true

require 'project_lint/ast'

module ProjectLint
  # Shared limits and native token categories for array layout.
  module ArrayLayoutRules
    ARRAY_WIDTH = 60
    LINE_WIDTH = 140
    SPACE = %i[WHITESPACE INDENT NEWLINE].freeze
    COMMENTS = %i[COMMENT SLASH_COMMENT MLCOMMENT].freeze
    OPEN = %i[LBRACK LBRACE LPAREN DQPRE].freeze
    CLOSE = %i[RBRACK RBRACE RPAREN DQPOST].freeze
    SIMPLE = [Ast::M::LiteralString, Ast::M::ConcatenatedString, Ast::M::LiteralInteger,
              Ast::M::LiteralFloat, Ast::M::LiteralBoolean, Ast::M::LiteralUndef,
              Ast::M::VariableExpression, Ast::M::QualifiedName].freeze
    MESSAGES = {
      compact: 'Use compact array layout: the array fits within 60 characters and the line within 140 characters',
      width: 'Use multiline array layout: the compact array exceeds 60 characters',
      complex: 'Use multiline array layout: the array contains complex elements',
      line: 'Use multiline array layout: required by the 140-character line layout',
      boundaries: 'Use one array element per line with separate opening and closing boundary lines'
    }.freeze
  end

  # Locate array boundaries without interpreting or rewriting element content.
  module ArrayLayoutSource
    include ArrayLayoutRules

    def closings
      stack = []
      @parts.each_index.with_object({}) do |index, result|
        stack << index if @parts[index].type == :LBRACK
        result[stack.pop] = index if @parts[index].type == :RBRACK && !stack.empty?
      end
    end

    def element_ranges(first, last)
      boundaries = [first, *element_separators(first, last), last]
      boundaries.each_cons(2).filter_map { |left, right| trimmed(left + 1, right - 1) }
    end

    def element_separators(first, last)
      depth = 0
      ((first + 1)...last).select do |index|
        type = @parts[index].type
        depth += 1 if OPEN.include?(type)
        depth -= 1 if CLOSE.include?(type)
        type == :COMMA && depth.zero?
      end
    end

    def trimmed(first, last)
      first += 1 while first <= last && formatting?(@parts[first])
      last -= 1 while first <= last && formatting?(@parts[last])
      (first..last) if first <= last
    end

    def formatting?(part)
      SPACE.include?(part.type) || COMMENTS.include?(part.type)
    end

    def text(range)
      @parts[range].map(&:to_manifest).join
    end

    def protected_content?(first, last)
      @parts[first..last].any? do |part|
        COMMENTS.include?(part.type) || part.type.to_s.start_with?('HEREDOC') ||
          (!SPACE.include?(part.type) && part.to_manifest.include?("\n"))
      end
    end

    def multiline_expression?(plan)
      plan[:elements].zip(plan[:node].values).any? do |range, value|
        !value.is_a?(Ast::M::LiteralList) && text(range).include?("\n")
      end
    end

    def contains?(parent, child)
      parent[:first] < child[:first] && parent[:last] > child[:last]
    end

    def separator_indexes
      @separator_indexes ||= arrays.flat_map { |plan| element_separators(plan[:first], plan[:last]) }
    end

    def protected_index?(index)
      arrays.any? { |plan| plan[:blocked] && index > plan[:first] && index < plan[:last] }
    end

    def owns_comma?(part)
      index = @parts.index(part)
      return true if separator_indexes.include?(index) || protected_index?(index)

      @parts.take(index).count { |entry| entry.type == :DQPRE } >
        @parts.take(index).count { |entry| entry.type == :DQPOST }
    end
  end

  # Classify AST nodes and protect complete containing regions.
  module ArrayLayoutAnalysis
    include ArrayLayoutRules

    def analyze(node, parents)
      return if parents.any? { |parent| string_node?(parent) }

      first = @positions[[node.line, node.pos]]
      last = @closings[first]
      return unless first && last

      describe({ node: node, first: first, last: last, elements: element_ranges(first, last),
                 extra: resource_indent(node, parents) })
    end

    def describe(plan)
      plan[:protected] = protected_content?(plan[:first], plan[:last])
      plan[:blocked] = plan[:protected] || uncertain_elements?(plan)
      plan[:candidate] = compact_candidate(plan)
      plan[:reason] = initial_reason(plan, plan[:candidate])
      plan[:compact] = plan[:reason] == :compact
      plan
    end

    def compact_candidate(plan)
      "[#{plan[:elements].map { |range| text(range) }.join(', ')}]"
    end

    def uncertain_elements?(plan)
      plan[:elements].length != plan[:node].values.length || multiline_expression?(plan)
    end

    def string_node?(node)
      node.is_a?(Ast::M::LiteralString) || node.is_a?(Ast::M::ConcatenatedString) || node.is_a?(Ast::M::HeredocExpression)
    end

    def resource_indent(node, parents)
      parents.last.is_a?(Ast::M::ResourceBody) && parents[-2].line == node.line ? 2 : 0
    end

    def simple?(node)
      SIMPLE.any? { |type| node.is_a?(type) } ||
        (node.is_a?(Ast::M::UnaryMinusExpression) &&
          [Ast::M::LiteralInteger, Ast::M::LiteralFloat].any? { |type| node.expr.is_a?(type) })
    end

    def initial_reason(plan, compact)
      return :boundaries if plan[:protected]
      return :compact if plan[:node].values.empty?
      return :complex unless plan[:node].values.all? { |node| simple?(node) }

      compact.length <= ARRAY_WIDTH ? :compact : :width
    end

    def protect_regions(ignored)
      @roots.each do |root|
        group = arrays.select { |plan| plan.equal?(root) || contains?(root, plan) }
        next unless blocked_region?(root, group, ignored)

        group.each { |plan| plan[:blocked] = true }
      end
    end

    def blocked_region?(root, group, ignored)
      ignored_region?(root, ignored) || group.any? { |plan| plan[:blocked] }
    end

    def ignored_region?(plan, ignored)
      (@parts[plan[:first]].line..@parts[plan[:last]].line).any? { |line| ignored.key?(line) }
    end
  end

  # Render a joint plan against the unchanged surrounding source.
  module ArrayLayoutRendering
    include ArrayLayoutRules

    def render
      @output = []
      @line = +''
      @line_number = 0
      @lines = []
      @placements = {}
      render_range(0, @parts.length - 1)
      @lines << @line
    end

    def append(part)
      @output << part
      segments = part.to_manifest.split("\n", -1)
      @line << segments.shift
      segments.each do |segment|
        @lines << @line.delete_suffix("\r")
        @line = segment.dup
        @line_number += 1
      end
    end

    def render_range(first, last)
      cursor = first
      cursor = render_at(cursor) while cursor <= last
    end

    def render_at(cursor)
      plan = @starts[cursor]
      if plan && !plan[:blocked]
        render_array(plan)
        return plan[:last] + 1
      end
      append(@parts[cursor])
      cursor + 1
    end

    def generated(type, value, anchor)
      append(PuppetLint::Lexer::Token.new(type, value, anchor.line, anchor.column))
    end

    def render_array(plan)
      start = @output.length
      opening = @parts[plan[:first]]
      indent = rendered_indent + plan[:extra]
      record_placement(plan)
      append(opening)
      render_elements(plan, indent, opening)
      append(@parts[plan[:last]])
      plan[:replacement] = @output[start..]
    end

    def rendered_indent
      @line[/\A[ \t]*/].gsub("\t", '  ').length
    end

    def record_placement(plan)
      @placements[plan[:first]] = @line_number if plan[:compact] && !plan[:elements].empty?
    end

    def render_elements(plan, indent, opening)
      plan[:elements].each_with_index do |range, index|
        element_prefix(plan, indent, opening, index)
        render_range(range.begin, range.end)
        generated(:COMMA, ',', opening) unless last_compact_element?(plan, index)
      end
      newline(indent, opening) unless plan[:compact]
    end

    def element_prefix(plan, indent, opening, index)
      return newline(indent + 2, opening) unless plan[:compact]

      generated(:WHITESPACE, ' ', opening) if index.positive?
    end

    def last_compact_element?(plan, index)
      plan[:compact] && index == plan[:elements].length - 1
    end

    def newline(indent, opening)
      generated(:NEWLINE, @newline, opening)
      generated(:INDENT, ' ' * indent, opening) if indent.positive?
    end
  end

  # Report proven deviations, including regions that cannot be rewritten safely.
  module ArrayLayoutReview
    include ArrayLayoutRules

    def changed?(plan)
      text(plan[:first]..plan[:last]) != plan[:replacement].map(&:to_manifest).join
    end

    def findings
      arrays.filter_map do |plan|
        next unless plan[:blocked] ? manual_deviation?(plan) : changed?(plan)

        [plan, diagnostic_message(plan)]
      end
    end

    def diagnostic_message(plan)
      reason = plan[:reason]
      reason = :boundaries if !plan[:compact] && @parts[plan[:first]].line != @parts[plan[:last]].line
      message = MESSAGES.fetch(reason)
      plan[:blocked] ? "#{message}; manual correction required [review]" : message
    end

    def manual_deviation?(plan)
      return changed?(plan) if plan[:replacement]
      return compact_deviation?(plan) if plan[:compact]
      return true if same_line_boundaries?(plan)
      return false if plan[:elements].length != plan[:node].values.length

      misplaced_elements?(plan) || missing_trailing_comma?(plan)
    end

    def compact_deviation?(plan)
      text(plan[:first]..plan[:last]) != plan[:candidate]
    end

    def same_line_boundaries?(plan)
      @parts[plan[:first]].line == @parts[plan[:last]].line
    end

    def element_starts(plan)
      plan[:node].values.map { |value| @parts[@positions.fetch([value.line, value.pos])] }
    end

    def misplaced_elements?(plan)
      opening = @parts[plan[:first]]
      indent = source_indent(opening.line) + plan[:extra]
      misplaced_start?(plan, opening.line, indent + 2) ||
        !indented?(@parts[plan[:last]], indent)
    end

    def misplaced_start?(plan, line, indent)
      element_starts(plan).any? { |part| part.line == line || !indented?(part, indent) }
    end

    def missing_trailing_comma?(plan)
      return false if plan[:elements].empty?

      tail = @parts[plan[:elements].last.end...plan[:last]].reject { |part| trailing_formatting?(part) }
      tail.last&.type != :COMMA
    end

    def trailing_formatting?(part)
      formatting?(part) || (part.type.to_s.start_with?('HEREDOC') && part.type != :HEREDOC_OPEN)
    end

    def source_indent(line)
      PuppetLint::Data.manifest_lines[line - 1][/\A[ \t]*/].gsub("\t", '  ').length
    end

    def indented?(part, width)
      PuppetLint::Data.manifest_lines[part.line - 1][0, part.column - 1] == ' ' * width
    end
  end

  # Plan all literal arrays together before changing native tokens.
  class ArrayLayout
    include ArrayLayoutSource
    include ArrayLayoutAnalysis
    include ArrayLayoutRendering
    include ArrayLayoutReview

    attr_reader :arrays, :replacements

    def initialize(tree, parts, ignored)
      prepare_source(parts)
      collect_arrays(tree)
      protect_regions(ignored)
      plan_widths
      @replacements = @roots.reject { |plan| plan[:blocked] || !changed?(plan) }
    end

    def plan_widths
      loop do
        render
        candidate = overflowing_candidate
        break unless candidate

        candidate[:compact] = false
        candidate[:reason] = :line
      end
    end

    def overflowing_candidate
      @lines.each_with_index do |line, index|
        next if line.length <= LINE_WIDTH

        first = @placements.select { |_opening, number| number == index }.keys.max
        return @starts.fetch(first) if first
      end
      nil
    end

    def prepare_source(parts)
      @parts = parts
      @newline = parts.find { |part| part.type == :NEWLINE }&.to_manifest || "\n"
      @positions = parts.each_index.to_h { |index| [[parts[index].line, parts[index].column], index] }
    end

    def collect_arrays(tree)
      @closings = closings
      @arrays = tree.each_node(Ast::M::LiteralList).filter_map { |node, parents| analyze(node, parents) }
      @starts = arrays.to_h { |plan| [plan[:first], plan] }
      @roots = arrays.reject { |plan| arrays.any? { |parent| contains?(parent, plan) } }
    end
  end
end
