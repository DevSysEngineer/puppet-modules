# frozen_string_literal: true

require_relative 'value_bounds'

module ProjectTools
  module Secrets
    # Locate shell data using the same quote/expansion state as word boundaries.
    # This supplies context only: TextScan still inspects every source character.
    class ShellContext < ValueBounds
      def initialize(text)
        super
        @data = []
        reset(0, shell: true)
        collect
      end

      def code?(offset)
        range = @data.bsearch { |_first, last| last > offset }
        !range || offset < range[0]
      end

      def collect
        while @index < @limit
          first = @index
          data = @quote || @stack.any? { |entry| entry.is_a?(Array) && entry[0] == '}' }
          data = advance_context? || data
          protect(first, @index) if data
        end
      end

      def advance_context?
        if !@quote && comment?
          @index = @text.index("\n", @index) || @limit
          return true
        end
        if !@quote && @text[@index, 2] == '<<'
          @index = heredoc_end
          return true
        end
        advance_syntax
        false
      end

      def comment?
        @text[@index] == '#' && (@index.zero? || @text[@index - 1].match?(/[\s;|&()]/))
      end

      def advance_syntax
        char = @text[@index]
        # A case label's closing parenthesis is not a bracket in the enclosing function.
        if PAIRS.value?(char) && !@quote && !@stack.empty? && Array(@stack.last).first != char
          @index += 1
        else
          @index += 1 unless step(char) == :continue
        end
      end

      def heredoc_end
        opening = /\A<<(-?)[ \t]*(['"]?)(\w+)\2[^\r\n]*\r?\n/.match(@text[@index..])
        return @limit unless opening && !opening[0][2..].include?('<<')

        start = @index + opening.end(0)
        indent = opening[1].empty? ? '' : '\t*'
        ending = /^#{indent}#{Regexp.escape(opening[3])}\r?(?:\n|\z)/.match(@text, start)
        ending ? ending.end(0) : @limit
      end

      def protect(first, last)
        if @data.last && @data.last[1] == first
          @data.last[1] = last
        else
          @data << [first, last]
        end
      end
    end
  end
end
