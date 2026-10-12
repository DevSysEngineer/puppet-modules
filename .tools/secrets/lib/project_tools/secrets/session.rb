# frozen_string_literal: true

require_relative 'store'
require_relative 'selection'
require_relative 'analysis'
require_relative 'source_versions'

module ProjectTools
  module Secrets
    # Publish only after the entire selection has been inspected and prepared.
    class Session
      attr_reader :data, :documents

      def initialize(root:, policy:, tree:, store:)
        @store = store
        @data = { 'root' => Paths.absolute(root), 'tree' => Paths.absolute(tree),
                  'policy_path' => Paths.absolute(policy), 'files' => {}, 'markers' => {}, 'destinations' => {} }
        @selection = Selection.new(data, store.directory)
      end

      def prepare
        @selection.prepare
        inspect_sources
        build_files
        @selection.destinations(documents)
        SourceVersions.verify(data)
        publish
      end

      def inspect_sources
        sources = @selection.files.to_h do |relative|
          [relative, SourceReader.local_read(Paths.inside(data['root'], relative))]
        end
        @documents = Scanner.documents(sources)
        Scanner.complete!(documents)
        raise Failure, 'reserved_marker_in_source' if sources.values.any? { |text| text.include?('[REDACTED-') }
      end

      def build_files
        documents.each do |document|
          safe = @selection.safe_path(document.path, documents)
          @selection.reserve!(safe)
          data['files'][safe] = Analysis.new(document, safe, data).prepare
        end
      end

      def publish
        files = data['files'].transform_values { |file| file['analysis'] }
        Output.new(documents, [data['root']]).analysis_tree(data['tree'], files)
        @created = true
        report(@store.create(data))
      rescue StandardError, SignalException
        withdraw
        raise
      end

      def withdraw
        FileUtils.remove_entry(data['tree']) if @created
      end

      def report(id)
        { 'operation' => 'prepare', 'complete' => true, 'prepared' => true, 'session' => id,
          'status' => findings? ? 'findings' : 'no_findings',
          'files' => file_records, 'context' => context }
      end

      def findings?
        !data['markers'].empty? || documents.any? { |doc| !doc.findings.empty? }
      end

      def file_records
        data['files'].map do |path, file|
          file.slice('coverage', 'context_omitted', 'writable').merge('file' => path)
        end
      end

      def context
        data['files'].filter_map do |safe, file|
          safe if data['policy'].fetch('context', []).include?(file['source'])
        end
      end
    end
  end
end
