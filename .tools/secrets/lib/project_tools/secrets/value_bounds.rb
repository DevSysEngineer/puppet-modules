# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Recognize complete quoted/balanced expressions without executing them.
    class ValueBounds
      PAIRS = { '(' => ')', '[' => ']', '{' => '}' }.freeze
      QUOTES = %w[' " `].freeze

      def initialize(text, puppet: false)
        @text = text
        @puppet = puppet
      end

      def finish(first, balanced: false, outer_quote: nil, word: false)
        return if @text[first..].start_with?('@(', '<<', '|', '>')

        @index = first
        @stack = []
        @quote = nil
        @outer_quote = outer_quote
        @word = word
        @lambda_start = nil
        @lambda_body = false
        walk(balanced)
      end

      def walk(balanced)
        while @index < @text.length
          state = step(@text[@index])
          return if state == :invalid
          return @index if state == :stop || (balanced && closed?)
        end
        end_offset
      end

      def end_offset
        @index if closed? && @index <= @text.length && !@outer_quote
      end

      def closed?
        @stack.empty? && !@quote && !@lambda_body
      end

      def lambda?
        !@lambda_start.nil?
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
        return lambda_body(char) if @lambda_body
        return :stop if terminator?(char)
        return :invalid if unsupported_marker?
        return closing(char) if PAIRS.value?(char)

        opening(char)
      end

      def terminator?(char)
        @stack.empty? && (char == @outer_quote || ",;\r\n".include?(char) || (@word && char.match?(/[ \t]/)))
      end

      def opening(char)
        return lambda_pipe if @puppet && char == '|'

        if QUOTES.include?(char)
          @quote = char
        elsif PAIRS.key?(char)
          @stack << PAIRS.fetch(char)
        end
        :continue
      end

      def lambda_pipe
        if @stack.last == '|'
          parameters = @text[@lambda_start...@index]
          return :invalid unless parameters.match?(/\A\s*\$\w+(?:\s*,\s*\$\w+)*\s*\z/)

          @stack.pop
          @lambda_body = true
        else
          @lambda_start = @index + 1
          @stack << '|'
        end
        :continue
      end

      def lambda_body(char)
        return :continue if char.match?(/\s/)
        return :invalid unless char == '{'

        @lambda_body = false
        @stack << '}'
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
