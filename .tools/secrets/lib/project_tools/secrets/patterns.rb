# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Deliberately bounded signatures, never entropy guesses or network validation.
    module Patterns
      NAME = /password|passwd|passphrase|(?:\A|_)pwd(?:\z|_)|secret|token|api[_-]?key|
              access[_-]?key|private[_-]?key|encryption[_-]?key|signing[_-]?key|license[_.-]?key|authorization/ix.freeze
      TOKENS = /\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|
                xox[baprs]-[A-Za-z0-9-]{10,}|(?:AKIA|ASIA)[A-Z0-9]{16}|
                sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{20,}|
                eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)(?![A-Za-z0-9_-])/x.freeze
      AUTH = %r{\b(?:Bearer|Basic)[ \t]+([A-Za-z0-9+/_=.-]{12,})}.freeze
      URL = %r{\b[a-z][a-z0-9+.-]*://([^\s/"'<>]+@)}i.freeze
      PEM = /-----BEGIN ([A-Z0-9 ]*(?:PRIVATE KEY|CERTIFICATE|CERTIFICATE REQUEST|PGP PRIVATE KEY BLOCK))-----/.freeze
      ENCRYPTED = /ENC\[/.freeze
      ASSIGNMENT = /["']?([\w:.-]+)["']?(?:[ \t]*\])?[ \t]*(?:=>|=(?!=|>)|(?<!:):(?!:))[ \t]*/.freeze
      SHELL_CASE_LABEL = /\A[ \t]*\(?[ \t]*[^\s"'`$();=\\|]+(?:[ \t]*\|[ \t]*[^\s"'`$();=\\|]+)*[ \t]*\)/.freeze
      SHELL_CASE_START = /(?:^[ \t]*case[ \t]+[^\r\n]+[ \t]+in|;;)[ \t]*(?:\#[^\r\n]*)?\r?\n
                         (?:[ \t]*(?:\#[^\r\n]*)?\r?\n)*\z/x.freeze
      EMPTY = /\A(?:|undef|null|nil|~|\[REDACTED\])\z/i.freeze
      REFERENCE = /\A(?:\$[\w:]+|\$\{[\w:]+\}|
                    lookup\(\s*['"][\w:.-]+['"]\s*(?:,\s*Sensitive\s*\[\s*String\s*\]\s*)?\))\z/x.freeze

      def self.each_match(text, pattern)
        text.to_enum(:scan, pattern).each { yield Regexp.last_match }
      end

      def self.signatures(document, pem_searches: [])
        matches(document, TOKENS, 'token_signature')
        matches(document, AUTH, 'authorization', group: 1)
        credential_urls(document)
        blocks(document, PEM, 'pem_material', searches: pem_searches) { |match| "-----END #{match[1]}-----" }
        blocks(document, ENCRYPTED, 'encrypted_secret') { ']' }
      end

      def self.credential_urls(document)
        each_match(document.text, URL) do |match|
          userinfo = match[1][0...-1]
          next if match[0].match?(%r{\A(?:ssh|git\+ssh)://}i) && userinfo.match?(/\A[\w.-]+\z/)

          document.redact(match.begin(1), match.end(1) - 1, 'credential_url', value: userinfo)
          document.values << userinfo.split(':', 2).last if userinfo.include?(':')
        end
      end

      def self.matches(document, pattern, rule, group: 0, trim: 0)
        each_match(document.text, pattern) do |match|
          document.redact(match.begin(group), match.end(group) - trim, rule)
        end
      end

      def self.block(document, match, pattern, rule, searches)
        ending = yield
        last = block_end(document.text, ending, match.end(0), searches)
        issue = block_issue(document, match, pattern, last, searches)
        document.finding(rule, match.begin(0), 'value')
        return document.error("#{issue}_#{rule}") if issue

        document.redact(match.begin(0), last + ending.length, rule)
      end

      def self.block_end(text, ending, start, searches)
        last = text.index(ending, start)
        last = text.index(ending, last + ending.length) while last && search_marker?(searches, last)
        last
      end

      def self.block_issue(document, match, pattern, last, searches)
        return 'unterminated' unless last

        nested = pattern == ENCRYPTED ? /\[/ : pattern
        each_match(document.text[match.end(0)...last], nested) do |inner|
          return 'nested' unless search_marker?(searches, match.end(0) + inner.begin(0))
        end
        nil
      end

      def self.search_marker?(searches, offset)
        searches.any? { |first, last| offset >= first && offset < last }
      end

      def self.blocks(document, pattern, rule, searches: [])
        each_match(document.text, pattern) do |match|
          next if search_marker?(searches, match.begin(0))

          block(document, match, pattern, rule, searches) { yield match }
        end
      end
    end
  end
end
