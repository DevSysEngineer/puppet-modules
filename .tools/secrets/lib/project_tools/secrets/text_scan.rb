# frozen_string_literal: true

require_relative 'patterns'
require_relative 'value_bounds'
require_relative 'context'
require_relative 'markdown_context'

module ProjectTools
  module Secrets
    # Bound assignment values and Puppet wrappers; names alone remain indicators.
    class TextScan
      def initialize(document)
        @document = document
        @text = document.text
        @markdown = MarkdownContext.new(@text) if %w[.md .markdown].include?(File.extname(document.path).downcase)
        @region = MarkdownContext::Region.new(0, @text.length, false)
      end

      def scan
        assignments
        command_options
        sensitive_calls
        Patterns.each_match(@text, /\b[\w:.-]+\b/) do |match|
          @document.finding('sensitive_name', match.begin(0)) if Patterns::NAME.match?(match[0])
        end
      end

      def command_options
        Patterns.each_match(@text, /--([\w-]+)[ \t]+(?=\S)/) do |match|
          next unless Patterns::NAME.match?(match[1])
          next unless within_context?(match)

          value(match.end(0), 'sensitive_assignment', name: match[1], word: true)
        end
      end

      def assignments
        Patterns.each_match(@text, Patterns::ASSIGNMENT) do |match|
          next unless Patterns::NAME.match?(match[1])
          next if Context.assignment_code?(@document, match)
          next unless within_context?(match)

          value(skip_space(match.end(0)), 'sensitive_assignment', name: match[1], word: match[1].start_with?('--'))
        end
      end

      def sensitive_calls
        Patterns.each_match(@text, /\bSensitive\b(?:\s*\.\s*new\b)?/) do |match|
          @document.finding('puppet_sensitive', match.begin(0))
          next unless within_context?(match)

          first = skip_space(match.end(0))
          next unless first < @region.last && @text[first] == '('

          last = bounds.finish(first, balanced: true)
          last ? redact(first + 1, last - 1, 'puppet_sensitive') : unbounded('puppet_sensitive')
        end
      end

      def within_context?(match)
        @region = @markdown.at(match.begin(0)) if @markdown
        match.end(0) <= @region.last || @document.error('unbounded_sensitive_value')
      end

      def bounds
        ValueBounds.new(@text, puppet: puppet_source?, limit: @region.last)
      end

      def unbounded(rule)
        return @document.error('unbounded_sensitive_value') unless @region.code

        @document.redact(@region.first, @region.last, rule)
      end

      def skip_space(index)
        index += 1 while index < @region.last && @text[index]&.match?(/[ \t\r\n]/)
        index
      end

      def value(first, rule, name: '', word: false)
        @document.finding(rule, first)
        return @document.error('unbounded_sensitive_value') if first >= @region.last
        return if @text[first...@region.last].match?(/\ASensitive\s*(?:\.\s*new\s*)?\(/)

        range = value_bounds(first, word)
        range ? redact(*range, rule, name: name) : unbounded(rule)
      end

      def value_bounds(first, word)
        parser = bounds
        last = parser.finish(first, outer_quote: parser.enclosing_quote(first, start: @region.first), word: word)
        return unless last && last > first && !ambiguous_continuation?(first, last, parser.lambda?)

        [first, last]
      end

      def ambiguous_continuation?(first, last, lambda_expression)
        return false if ruby_source?

        # Only a proven code fragment can rule out continuation in the following text.
        tail = @text[last...(@region.code ? @region.last : @text.length)]
        return false unless tail.match?(/\A\r?\n/)

        following = tail.lines.find { |line| /\S/.match?(line) }
        return false unless following.to_s.match?(/\A[ \t]+\S/)
        return false if puppet_statement?(first, last, lambda_expression)

        !following.match?(/\A[ \t]*(?:[#}\]);]|["'$]?[\w:.-]+["']?\s*(?:=>|=|:))/)
      end

      def puppet_source?
        File.extname(@document.path) == '.pp'
      end

      def puppet_statement?(first, last, lambda_expression)
        return false unless puppet_source? && puppet_expression?(first, last, lambda_expression)

        start = skip_space(last)
        return false unless @text[start..].match?(/\A(?:if|unless)\s+[^\r\n{]+\{/)

        opening = @text.index('{', start)
        !!ValueBounds.new(@text, puppet: true).finish(opening, balanced: true)
      end

      def puppet_expression?(first, last, lambda_expression)
        expression = @text[first...last].strip
        (lambda_expression && expression.end_with?('}')) ||
          expression.match?(/\A\$[\w:]+(?:\[[^\r\n]+\]|\.[a-z_]\w*)*\z/)
      end

      def ruby_source?
        @document.ruby_source? && @document.complete?
      end

      def redact(first, last, rule, name: '')
        raw = @text[first...last].strip
        return if Context.safe_value?(name, raw)

        @document.redact(first, last, rule, "'[REDACTED]'", value: Context.unquote(raw))
      end
    end
  end
end
