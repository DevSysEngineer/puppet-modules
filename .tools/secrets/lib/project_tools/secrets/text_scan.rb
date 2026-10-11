# frozen_string_literal: true

require_relative 'patterns'
require_relative 'value_bounds'
require_relative 'context'

module ProjectTools
  module Secrets
    # Bound assignment values and Puppet wrappers; names alone remain indicators.
    class TextScan
      def initialize(document)
        @document = document
        @text = document.text
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

          value(match.end(0), 'sensitive_assignment', name: match[1], word: true)
        end
      end

      def assignments
        Patterns.each_match(@text, Patterns::ASSIGNMENT) do |match|
          next unless Patterns::NAME.match?(match[1])
          next if rake_task?(match)

          value(skip_space(match.end(0)), 'sensitive_assignment', name: match[1], word: match[1].start_with?('--'))
        end
      end

      def sensitive_calls
        Patterns.each_match(@text, /\bSensitive\b(?:\s*\.\s*new\b)?/) do |match|
          @document.finding('puppet_sensitive', match.begin(0))
          first = skip_space(match.end(0))
          next unless @text[first] == '('

          last = ValueBounds.new(@text).finish(first, balanced: true)
          last ? redact(first + 1, last - 1, 'puppet_sensitive') : @document.error('unbounded_sensitive_value')
        end
      end

      def skip_space(index)
        index += 1 while @text[index]&.match?(/[ \t\r\n]/)
        index
      end

      def value(first, rule, name: '', word: false)
        @document.finding(rule, first)
        return if @text[first..].match?(/\ASensitive\s*(?:\.\s*new\s*)?\(/)

        bounds = value_bounds(first, word)
        bounds ? redact(*bounds, rule, name: name) : @document.error('unbounded_sensitive_value')
      end

      def value_bounds(first, word)
        last = ValueBounds.new(@text).finish(first, outer_quote: enclosing_quote(first), word: word)
        return unless last && last > first && !ambiguous_continuation?(last)

        [first, last]
      end

      def ambiguous_continuation?(last)
        return false if ruby_source?
        return false unless @text[last..].match?(/\A\r?\n/)

        following = @text[(last + 1)..].lines.find { |line| !line.strip.empty? }
        return false unless following&.match?(/\A[ \t]+\S/)

        !following.match?(/\A[ \t]*(?:[#}\]);]|["'$]?[\w:.-]+["']?\s*(?:=>|=|:))/)
      end

      def ruby_source?
        @document.ruby_source? && @document.complete?
      end

      def enclosing_quote(first)
        start = (@text.rindex("\n", first - 1) || -1) + 1
        quote = nil
        @text[start...first].scan(/\\.|['"`]/).each do |char|
          next if char.start_with?('\\')

          quote = quote == char ? nil : quote || char
        end
        quote
      end

      def rake_task?(match)
        match[0].end_with?(':') && @text[0...match.begin(0)].match?(/\brake[ \t]+['"]?\z/)
      end

      def redact(first, last, rule, name: '')
        raw = @text[first...last].strip
        return if Patterns::EMPTY.match?(raw) || Patterns::REFERENCE.match?(raw)
        return if Context::ERB_REFERENCE.match?(unquote(raw))
        return if Context.metadata?(name, unquote(raw)) || Context.file_reference?(name, unquote(raw))

        @document.redact(first, last, rule, "'[REDACTED]'", value: unquote(raw))
      end

      def unquote(value)
        return value[1...-1] if value.length >= 2 && %w[' "].include?(value[0]) && value[-1] == value[0]

        value
      end
    end
  end
end
