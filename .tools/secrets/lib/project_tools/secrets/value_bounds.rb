# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Recognize complete quoted/balanced expressions without executing them.
    class ValueBounds
      PAIRS = { '(' => ')', '[' => ']', '{' => '}' }.freeze

      def initialize(text, limit: text.length)
        @text = text
        @limit = limit
      end

      def finish(first, balanced: false, outer_quote: nil, word: false, shell: false)
        return if @text[first...@limit].start_with?('@(', '<<', '|', '>')

        reset(first, outer_quote: outer_quote, word: word, shell: shell)
        walk(balanced)
      end

      def reset(first, outer_quote: nil, word: false, shell: false)
        @index = first
        @stack = []
        @quote = nil
        @outer_quote = outer_quote
        @word = word || shell
        @shell = shell
      end

      def walk(balanced)
        while @index < @limit
          state = step(@text[@index])
          return if state == :invalid
          return @index if state == :stop || (balanced && closed?)
        end
        end_offset
      end

      def end_offset
        @index if closed? && @index <= @limit && !@outer_quote
      end

      def closed?
        @stack.empty? && !@quote
      end

      def followed_by_statement?(_first, _last)
        false
      end

      def step(char)
        if char == '\\' && !(@shell && @quote == "'")
          @index += 2
          return :continue
        end
        return :continue if shell_expansion?

        state = @quote ? quoted(char) : unquoted(char)
        @index += 1 if state == :continue
        state
      end

      def shell_expansion?
        return false unless @shell && @quote != "'" && ['${', '$('].include?(@text[@index, 2])

        @stack << [PAIRS.fetch(@text[@index + 1]), @quote]
        @quote = nil
        @index += 2
        true
      end

      def quoted(char)
        @quote = nil if char == @quote
        :continue
      end

      def unquoted(char)
        return :stop if terminator?(char)
        return :invalid if @index + 2 <= @limit && ['@(', '<<'].include?(@text[@index, 2])
        return closing(char) if PAIRS.value?(char)

        opening(char)
      end

      def terminator?(char)
        separators = @shell ? ";\r\n|&<>" : ",;\r\n"
        @stack.empty? && (char == @outer_quote || separators.include?(char) || (@word && char.match?(/[ \t]/)))
      end

      def opening(char)
        if %q('"`).include?(char)
          @quote = char
        elsif PAIRS.key?(char)
          @stack << PAIRS.fetch(char)
        end
        :continue
      end

      def closing(char)
        return :stop if @stack.empty?

        expected, @quote = @stack.pop
        return :invalid unless expected == char

        :continue
      end
    end
  end
end
