# frozen_string_literal: true

require_relative 'value_bounds'

module ProjectTools
  module Secrets
    # Bound Puppet lambdas, selectors and following conditionals without a Puppet runtime.
    class PuppetBounds < ValueBounds
      REFERENCE = /\A\$[\w:]+(?:\[[^\r\n]+\]|\.[a-z_]\w*)*\z/.freeze

      def followed_by_statement?(first, last)
        return false unless complete_expression?(@text[first...last].strip)
        return false unless @text[last..].match?(/\A\s*(?:if|unless)\s+[^\r\n{]+\{/)

        opening = @text.index('{', last)
        !!self.class.new(@text).finish(opening, balanced: true)
      end

      def complete_expression?(expression)
        return true if @lambda_start && expression.end_with?('}')
        return true if REFERENCE.match?(expression)

        selector = /\?[ \t]*(?=\{)/.match(expression)
        return false unless selector && REFERENCE.match?(expression[0...selector.begin(0)].rstrip)

        self.class.new(expression).finish(selector.end(0), balanced: true) == expression.length
      end

      def reset(...)
        super
        @lambda_start = nil
        @lambda_body = false
      end

      def closed?
        super && !@lambda_body
      end

      def step(char)
        return super unless char == '#' && !@quote && !@stack.empty? && comment_line?

        @index = [@text.index(/[\r\n]/, @index) || @limit, @limit].min
        :continue
      end

      def comment_line?
        start = (@text.rindex(/[\r\n]/, @index - 1) || -1) + 1
        @text[start...@index].match?(/\A[ \t]*\z/)
      end

      def unquoted(char)
        return super unless @lambda_body
        return :continue if char.match?(/\s/)
        return :invalid unless char == '{'

        @lambda_body = false
        opening(char)
      end

      def opening(char)
        char == '|' ? lambda_pipe : super
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
    end
  end
end
