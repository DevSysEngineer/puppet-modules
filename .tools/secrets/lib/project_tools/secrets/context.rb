# frozen_string_literal: true

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
