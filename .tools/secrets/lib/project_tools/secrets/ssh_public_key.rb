# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Public records require disclosure protection, independently of Puppet credential policy.
    module SshPublicKey
      RECORD = %r{(?<![\w@-])(?:ssh-(?:rsa|dss|ed25519|mldsa44-ed25519)|
                 ecdsa-sha2-nistp(?:256|384|521)|sk-(?:ssh-ed25519|ecdsa-sha2-nistp256))
                (?:-cert-v01@openssh\.com|@openssh\.com)?[ \t\r\n]+
                ([A-Za-z0-9+/]{20,}={0,3})}x.freeze

      def self.encoded_values(text)
        text.scan(RECORD).flatten
      end

      def self.known_values(document)
        texts = [document.text, *document.literals.map { |literal| literal[2] }.grep(String)]
        texts.flat_map { |text| encoded_values(text) }.uniq
      end

      def self.quoted_literal?(source, value)
        ["'", '"'].include?(source[0]) && source[-1] == source[0] && source[1...-1] == value
      end

      def self.scan(document)
        protected = protect_literals(document)
        Patterns.each_match(document.text, RECORD) do |match|
          document.values << match[1]
          next if protected.any? { |first, last| match.begin(0) >= first && match.end(0) <= last }

          protect_source(document)
        end
      end

      def self.protect_literals(document)
        document.literals.filter_map do |first, last, value, type|
          next unless value.is_a?(String) && RECORD.match?(value)

          protect_literal(document, first, last, value, type)
          document.values.concat(encoded_values(value))
          [first, last]
        end
      end

      def self.protect_literal(document, first, last, value, type)
        return protect_source(document) if type == 'puppet' && !quoted_literal?(document.text[first...last], value)

        document.redact(first, last, 'ssh_public_key', '"[REDACTED]"', value: value)
      end

      def self.protect_source(document)
        # Without a parser-owned value boundary, options and comments may span the source.
        replacement = File.extname(document.path).downcase == '.json' ? '"[REDACTED]"' : '# [REDACTED]'
        document.redact(0, document.text.length, 'ssh_public_key', replacement)
      end
    end
  end
end
