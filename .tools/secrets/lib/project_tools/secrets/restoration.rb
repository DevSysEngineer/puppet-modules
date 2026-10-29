# frozen_string_literal: true

require_relative 'marker_integrity'

module ProjectTools
  module Secrets
    # Restored bytes stay local; plain new values cannot bypass marker registration.
    class Restoration
      attr_reader :integrity, :documents

      def initialize(data, changes)
        @data = data
        @changes = changes
        @documents = Scanner.documents(changes.final)
        Scanner.complete!(documents)
        @integrity = MarkerIntegrity.new(data, changes, documents)
        integrity.verify
      end

      def candidates
        documents.to_h { |document| [document.path, restore(document)] }
      end

      def restore(document)
        original = @changes.original(document.path)
        return opaque(original, document) if original && !original.fetch('writable', true)

        edits = replacements(document)
        reject_plain_values(document, edits)
        apply_edits(document.text, edits)
      end

      def replacements(document)
        integrity.sites[document.path].map { |site| document.restore(site, @data['markers'].fetch(site['id'])) }
      end

      def apply_edits(text, edits)
        # MarkerIntegrity validated the analysis; restored literals may contain marker examples.
        restored = text.dup
        edits.sort_by(&:first).reverse_each { |first, last, raw| restored[first...last] = raw }

        restored
      end

      def opaque(original, document)
        raise Failure, 'write_unsupported' unless original['analysis'] == document.text

        original['original']
      end

      def reject_plain_values(document, edits)
        document.merged_spans.each do |first, last, _replacement|
          outside = unprotected(document.text, first, last, edits)
          member = document.ruby_containers&.member(first, last)
          outside = outside.sub(/=>\s*\z/, '') if member && member[:kind] == :key
          raise Failure, 'unregistered_value' unless outside.gsub(/["'\s]/, '').empty?
        end
      end

      def unprotected(text, first, last, edits)
        outside = text[first...last].dup
        edits.sort_by(&:first).reverse_each do |start, finish, _raw|
          next unless start >= first && finish <= last

          outside[(start - first)...(finish - first)] = ''
        end
        outside
      end
    end
  end
end
