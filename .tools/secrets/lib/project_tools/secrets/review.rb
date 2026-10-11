# frozen_string_literal: true

require_relative 'review_policy'

module ProjectTools
  module Secrets
    # An explicit, content-bound review never changes the inspection of another file.
    class Review
      def initialize(path)
        @entries = ReviewPolicy.new(path).entries
      end

      def apply(documents)
        documents.each do |document|
          entry = @entries[canonical_path(document.path)]
          next unless entry

          if matches?(entry, document)
            document.accept_review(entry['control'])
          else
            document.error('review_mismatch')
          end
        end
      end

      def matches?(entry, document)
        return false unless document.fingerprint == entry['sha256'] && document.members.empty?

        document.errors.sort == entry['errors'].sort &&
          sorted_findings(document.findings) == sorted_findings(entry['findings'])
      end

      def sorted_findings(findings)
        findings.map { |item| item.transform_keys(&:to_s) }.sort_by do |item|
          [item['line'], item['rule'], item['kind']]
        end
      end

      def canonical_path(path)
        File.realpath(path)
      rescue SystemCallError
        nil
      end
    end
  end
end
