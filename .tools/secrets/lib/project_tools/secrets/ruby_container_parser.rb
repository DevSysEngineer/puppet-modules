# frozen_string_literal: true

require 'ripper'

module ProjectTools
  module Secrets
    # Locate literal container members with native Ruby parser events, without executing source.
    class RubyContainerParser < Ripper::SexpBuilderPP
      attr_reader :containers

      def initialize(document)
        @document = document
        @text = document.text
        @lines = @text.lines
        @open = { square: [], brace: [] }
        @closed = {}
        @nodes = {}.compare_by_identity
        @strings = {}.compare_by_identity
        @containers = []
        super(@text)
        parse
      end

      def offset(line = lineno, byte = column)
        @lines.first(line - 1).sum(&:length) + @lines.fetch(line - 1, '').byteslice(0, byte).to_s.length
      end

      { lbracket: :square, lbrace: :brace, tlambeg: :brace }.each do |event, kind|
        define_method("on_#{event}") do |token|
          @open[kind] << offset
          super(token)
        end
      end

      { rbracket: :square, rbrace: :brace }.each do |event, kind|
        define_method("on_#{event}") do |token|
          @closed[[kind, offset + token.length]] = @open[kind].pop
          super(token)
        end
      end

      def on_string_literal(content)
        node = super
        @strings[node] = @document.literals.find { |_, last, _, type| last == offset && type == 'ruby' }
        node
      end

      def on_array(elements)
        node = super
        children = (elements || []).map { |element| scalar(element) }
        remember(node, :array, :square, children) if children.none?(&:nil?)
        node
      end

      def on_hash(associations)
        node = super
        children = associations ? associations[1].map { |pair| association(pair) } : []
        remember(node, :hash, :brace, children.flatten(1)) if children.none?(&:nil?)
        node
      end

      def remember(node, kind, delimiter, children)
        first = @closed[[delimiter, offset]]
        return unless first

        value = { first: first, last: offset, kind: kind, children: children }
        @nodes[node] = value
        containers << value
      end

      def scalar(node)
        return unless node.is_a?(Array)
        return @nodes[node] if @nodes.key?(node)

        range = scalar_range(node)
        { first: range[0], last: range[1], kind: :scalar } if range
      end

      def scalar_range(node)
        case node[0]
        when :string_literal then @strings[node]&.first(2)
        when :@int, :@float, :@label then token_range(node)
        when :var_ref then keyword_range(node[1])
        when :symbol_literal then symbol_range(node)
        when :unary then unary_range(node)
        end
      end

      def keyword_range(terminal)
        token_range(terminal) if terminal[0] == :@kw && %w[true false nil].include?(terminal[1])
      end

      def token_range(token)
        first = offset(*token[2])
        [first, first + token[1].length]
      end

      def symbol_range(node)
        terminal = node.dig(1, 1)
        return unless terminal.is_a?(Array) && %i[@ident @const @op @kw].include?(terminal[0])

        first, last = token_range(terminal)
        [first - 1, last] if @text[first - 1] == ':'
      end

      def unary_range(node)
        return unless %i[+@ -@].include?(node[1]) && %i[@int @float].include?(node.dig(2, 0))

        first, last = token_range(node[2])
        prefix = @text[0...first].match(/[+-]\s*\z/)
        [prefix.begin(0), last] if prefix
      end

      def association(pair)
        return unless pair[0] == :assoc_new

        key = scalar(pair[1])
        value = scalar(pair[2])
        return unless key && value && key[:kind] == :scalar

        last = key_end(key, value, pair[1][0] == :@label)
        return unless last

        [key.merge(kind: :key, last: last, value_last: key[:last]), value]
      end

      def key_end(key, value, label)
        return key[:last] if label

        separator = @text[key[:last]...value[:first]].match(/\A\s*=>/)
        key[:last] + separator.end(0) if separator
      end
    end
  end
end
