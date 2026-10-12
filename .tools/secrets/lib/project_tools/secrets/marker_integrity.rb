# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Intent is checked globally before restoring any occurrence.
    class MarkerIntegrity
      attr_reader :sites, :report

      def initialize(data, changes, documents)
        @data = data
        @changes = changes
        @documents = documents
        @sites = documents.to_h { |document| [document.path, document.marker_sites] }
        @report = []
      end

      def verify
        verify_counts
        @documents.each { |document| verify_document(document) }
        @changes.removed.each { |id| report << { 'id' => id, 'action' => 'removed' } }
      end

      def verify_counts
        counts = sites.values.flatten.group_by { |site| site['id'] }
        raise Failure, 'duplicate_marker' if counts.values.any? { |items| items.length != 1 }

        verify_intent(counts.keys)
      end

      def verify_intent(ids)
        raise Failure, 'unknown_marker' unless (ids - @data['markers'].keys).empty?

        removed = @data['markers'].keys - ids
        raise Failure, 'missing_marker' unless removed.sort == @changes.removed.sort

        verify_moves(ids)
      end

      def verify_moves(ids)
        raise Failure, 'unknown_marker' unless (@changes.moves.keys - ids).empty?
      end

      def verify_document(document)
        raise Failure, 'damaged_marker' if document.text.gsub(Document::MARKER, '').include?('[REDACTED-')

        sites[document.path].each do |site|
          verify_site(document, site)
        end
      end

      def verify_site(document, site)
        entry = @data['markers'].fetch(site['id'])
        verify_destination(document.path, site, entry)
        verify_role(document, site, entry)
        report << { 'id' => site['id'], 'action' => action(document.path, entry), 'file' => document.path }
      end

      def verify_destination(path, site, entry)
        destination = @changes.moves.fetch(site['id'], entry['file'])
        return if [path, @changes.origins[path]].include?(destination)

        raise Failure, 'unintended_marker_move'
      end

      def verify_role(document, site, entry)
        return unless entry['role']
        return if @changes.moves.key?(site['id'])

        first = site['literal'] ? site['literal'][0] : site['first'] - entry['replacement'].index('[REDACTED]')
        raise Failure, 'unintended_marker_move' unless entry['role'] == document.marker_role(first)
      end

      def action(path, entry)
        return 'reused' if entry['clone_of']

        entry['file'] == path ? 'preserved' : 'moved'
      end
    end
  end
end
