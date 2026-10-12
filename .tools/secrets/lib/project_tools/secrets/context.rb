# frozen_string_literal: true

require_relative 'patterns'

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

      def self.safe_value?(name, raw)
        return true if Patterns::EMPTY.match?(raw) || Patterns::REFERENCE.match?(raw)

        value = unquote(raw)
        ERB_REFERENCE.match?(value) || metadata?(name, value) || file_reference?(name, value)
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
