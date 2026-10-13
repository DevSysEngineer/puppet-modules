# frozen_string_literal: true

require_relative 'patterns'
require_relative 'value_bounds'
require_relative 'shell_context'

module ProjectTools
  module Secrets
    # Recognize documented value roles; a suffix or a number alone is insufficient.
    module Context
      COUNT = /\A(?:\w+::)*api_key_count\z/i.freeze
      POLICY = /\Apassword[._-](?:min_?length|retry_?limit|expiration|expire|expiry|min_age|max_age)\z/i.freeze
      LIFETIME = /\Atoken[._-](?:expire|expiry|ttl|lifetime)\z/i.freeze
      DURATION = /\A\d+(?:[smhdw])?\z/i.freeze
      ERB_REFERENCE = /\A<%=\s*(?:@[a-z_]\w*(?:\.unwrap)?|ENV\[['"][A-Z_]\w*['"]\])\s*%>\z/i.freeze
      FILE_SOURCE = %r{\Apuppet:///[^\s?#'"<>]+\z}.freeze
      GREP_PATTERN = %r{(?:^|[ \t;|&])(?:(?:/[\w/.-]+/)?(?:grep|egrep|fgrep)|"?\$(?:\w+|\{\w+\})"?)
                       [ \t]+(?:(?:--|--?[\w-]+)[ \t]+)*(['"])}x.freeze
      AWK_PATTERN = %r{(?:^[ \t]*|,[ \t]*)/((?:\\.|[^/\\\r\n])*)/[ \t]*(?=[,\{])}.freeze
      PEM_MARKER = /-----((?:BEGIN|END) [A-Z0-9 ]+)-----/.freeze

      def self.assignment_code?(document, match)
        rake = match[0].end_with?(':') && document.text[0...match.begin(0)].match?(/\brake[ \t]+['"]?\z/)
        rake || shell_case_label?(document.path, document.text, match)
      end

      def self.shell_case_label?(path, text, match)
        return false unless match[0].rstrip.end_with?(':')
        return false unless shell_source?(path, text)

        first = (text[0...match.begin(0)].rindex("\n") || -1) + 1
        return false unless Patterns::SHELL_CASE_START.match?(text[0...first])

        label = Patterns::SHELL_CASE_LABEL.match(text[first..])
        label && match.end(0) <= first + label.end(0)
      end

      def self.shell_source?(path, text)
        File.extname(path) == '.sh' || text.match?(/\A\#![^\r\n]*\b(?:ba)?sh\b/)
      end

      def self.empty_shell_assignment?(text, match)
        match[0].match?(/\A[\w-]+=[ \t]*\z/) &&
          text[match.begin(0) + match[1].length + 1].to_s.match?(/\A(?:[\s;|&<>]|\z)/)
      end

      def self.puppet_statement?(document, first, last, lambda_expression)
        return false unless File.extname(document.path) == '.pp'

        text = document.text
        return false unless puppet_expression?(text[first...last].strip, lambda_expression)
        return false unless text[last..].match?(/\A\s*(?:if|unless)\s+[^\r\n{]+\{/)

        opening = text.index('{', last)
        !!ValueBounds.new(text, puppet: true).finish(opening, balanced: true)
      end

      def self.puppet_expression?(expression, lambda_expression)
        (lambda_expression && expression.end_with?('}')) ||
          expression.match?(/\A\$[\w:]+(?:\[[^\r\n]+\]|\.[a-z_]\w*)*\z/)
      end

      def self.pem_searches(document)
        shell = shell_source?(document.path, document.text)
        return [] unless shell || File.extname(document.path) == '.awk'

        ranges = shell ? grep_searches(document.text) : []
        Patterns.each_match(document.text, AWK_PATTERN) do |match|
          ranges << [match.begin(1), match.end(1)] if pem_search_pattern?(match[1])
        end
        ranges
      end

      def self.grep_searches(text)
        ranges = []
        source = ShellContext.new(text)
        Patterns.each_match(text, GREP_PATTERN) do |match|
          next unless source.code?(match.begin(0))

          range = grep_pattern_bounds(text, match.begin(1))
          ranges << range if range && pem_search_pattern?(text[range[0]...range[1]])
        end
        ranges
      end

      def self.grep_pattern_bounds(text, first)
        last = ValueBounds.new(text).finish(first, balanced: true, shell: true)
        return unless last && (last == text.length || text[last].match?(/[\s;|&<>)]/))

        [first + 1, last - 1]
      end

      def self.pem_search_pattern?(pattern)
        return false if pattern.match?(/[\r\n]|\\[nr]/) || pattern.scan(PEM_MARKER).length != 1

        marker = PEM_MARKER.match(pattern)
        # A complete marker alternative has anchors/grouping, never a material body.
        pattern[0...marker.begin(0)].match?(/\A\^\(*\z/) &&
          pattern[marker.end(0)..].match?(/\A[)$]*(?:\|[^\r\n]*)?\z/)
      end

      def self.safe_value?(name, raw, shell: false)
        return true if Patterns::EMPTY.match?(raw) || reference?(raw, shell)

        value = unquote(raw)
        ERB_REFERENCE.match?(value) || metadata?(name, value) || file_reference?(name, value)
      end

      def self.reference?(raw, shell)
        Patterns::REFERENCE.match?(raw) || (shell && raw.match?(/\A"\$(?:\w+|\{[\w:]+\})"\z/))
      end

      def self.enclosing_quote(text, first, start: 0)
        start = [start, (text.rindex("\n", first - 1) || -1) + 1].max
        quote = nil
        text[start...first].scan(/\\.|['"`]/).each do |char|
          next if char.start_with?('\\')

          quote = quote == char ? nil : quote || char
        end
        quote
      end

      def self.unquote(value)
        return value[1...-1] if value.length >= 2 && %w[' "].include?(value[0]) && value[-1] == value[0]

        value
      end

      def self.metadata?(name, value)
        return true if COUNT.match?(name) && value.match?(/\A\d+\z/)
        return true if POLICY.match?(name) && value.match?(/\A\d+\z/)

        LIFETIME.match?(name) && DURATION.match?(value)
      end

      def self.file_reference?(name, value)
        name.match?(/private[_-]?key/i) && FILE_SOURCE.match?(value)
      end
    end
  end
end
