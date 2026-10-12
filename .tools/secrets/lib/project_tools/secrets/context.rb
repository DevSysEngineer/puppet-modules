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
