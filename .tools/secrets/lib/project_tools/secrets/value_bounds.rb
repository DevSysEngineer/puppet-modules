# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Recognize complete quoted/balanced expressions without executing them.
    class ValueBounds
      PAIRS = { '(' => ')', '[' => ']', '{' => '}' }.freeze
      QUOTES = %w[' " `].freeze

      def initialize(text)
        @text = text
      end

      def finish(first, balanced: false)
        return if @text[first..].start_with?('@(', '<<', '|', '>')

        @index = first
        @stack = []
        @quote = nil
        walk(balanced)
      end

      def walk(balanced)
        while @index < @text.length
          state = step(@text[@index])
          return if state == :invalid
          return @index if state == :stop || (balanced && closed?)
        end
        @index if closed?
      end

      def closed?
        @stack.empty? && !@quote
      end

      def step(char)
        if char == '\\'
          @index += 2
          return :continue
        end
        state = @quote ? quoted(char) : unquoted(char)
        @index += 1 if state == :continue
        state
      end

      def quoted(char)
        @quote = nil if char == @quote
        :continue
      end

      def unquoted(char)
        return :invalid if unsupported_marker?
        return closing(char) if PAIRS.value?(char)
        return :stop if @stack.empty? && ",;\r\n".include?(char)

        opening(char)
      end

      def opening(char)
        if QUOTES.include?(char)
          @quote = char
        elsif PAIRS.key?(char)
          @stack << PAIRS.fetch(char)
        end
        :continue
      end

      def unsupported_marker?
        ['@(', '<<'].include?(@text[@index, 2])
      end

      def closing(char)
        return :stop if @stack.empty?

        @stack.pop == char ? :continue : :invalid
      end
    end
  end
end
