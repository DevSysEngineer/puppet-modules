# frozen_string_literal: true

require_relative 'patterns'
require_relative 'value_bounds'

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
        sensitive_calls
        Patterns.each_match(@text, /\b[\w:.-]+\b/) do |match|
          @document.finding('sensitive_name', match.begin(0)) if Patterns::NAME.match?(match[0])
        end
      end

      def assignments
        Patterns.each_match(@text, Patterns::ASSIGNMENT) do |match|
          next unless Patterns::NAME.match?(match[1])

          value(skip_space(match.end(0)), 'sensitive_assignment')
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

      def value(first, rule)
        @document.finding(rule, first)
        return if @text[first..].match?(/\ASensitive\s*(?:\.\s*new\s*)?\(/)

        last = ValueBounds.new(@text).finish(first)
        if !last || last == first || ambiguous_continuation?(last)
          @document.error('unbounded_sensitive_value')
        else
          redact(first, last, rule)
        end
      end

      def ambiguous_continuation?(last)
        return false unless @text[last..].match?(/\A\r?\n/)

        following = @text[(last + 1)..].lines.find { |line| !line.strip.empty? }
        return false unless following&.match?(/\A[ \t]+\S/)

        !following.match?(/\A[ \t]*(?:[#}\]);]|["'$]?[\w:.-]+["']?\s*(?:=>|=|:))/)
      end

      def redact(first, last, rule)
        raw = @text[first...last].strip
        return if Patterns::EMPTY.match?(raw) || Patterns::REFERENCE.match?(raw)

        @document.redact(first, last, rule, "'[REDACTED]'", value: unquote(raw))
      end

      def unquote(value)
        return value[1...-1] if value.length >= 2 && %w[' "].include?(value[0]) && value[-1] == value[0]

        value
      end
    end
  end
end
