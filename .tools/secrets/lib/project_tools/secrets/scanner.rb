# frozen_string_literal: true

require_relative 'document'
require_relative 'text_scan'
require_relative 'yaml_scan'
require_relative 'puppet_scan'
require_relative 'source_reader'

module ProjectTools
  module Secrets
    # Selection includes hidden files; skipped or unreadable sources are errors.
    class Scanner
      def self.documents(sources, analysis: true)
        reader = SourceReader.new
        documents = sources.map { |path, bytes| reader.inspect_bytes(path, bytes.dup) }
        Scanner.new(analysis: analysis).scan_documents(documents)
      end

      def self.complete!(documents)
        raise Failure, 'inspection_incomplete' unless documents.all?(&:complete?)
      end

      def self.puppet!(documents)
        manifests = documents.select { |document| File.extname(document.path) == '.pp' }
        complete!(manifests)
        raise Failure, 'puppet_policy_rejected' if manifests.any? { |document| !document.findings.empty? }
      end

      MAX_BYTES = SourceReader::MAX_BYTES
      attr_reader :documents

      def initialize(puppet: false, analysis: false)
        @documents = []
        @seen = {}
        @puppet = puppet
        @analysis = analysis
        @reader = SourceReader.new
      end

      def scan(paths)
        select_paths(paths)
        inspect_documents
      end

      # Candidate bytes use the same detector without rereading the source files.
      def scan_documents(documents)
        @documents = documents
        inspect_documents
      end

      def inspect_documents
        scan_yaml
        leaves.each { |document| scan_text(document) }
        documents.each(&:aggregate)
        documents
      rescue StandardError, SystemStackError, SignalException
        documents.each { |document| document.error('inspection_failed') }
        raise
      end

      def select_paths(paths)
        paths.each { |path| select(File.expand_path(path)) }
        problem(paths.first, 'no_puppet_manifests') if @puppet && documents.empty?
      end

      def scan_yaml
        yaml = yaml_documents.map { |doc| YamlScan.new(doc) }
        selectors = yaml.flat_map(&:selectors).uniq
        yaml.each { |scanner| scanner.scan(selectors) }
        unresolved_hiera_scope if documents.any? { |doc| doc.errors.include?('unsupported_hiera_selector') }
      end

      def yaml_documents
        leaves.select { |doc| doc.complete? && yaml?(doc) }
      end

      def leaves(selected = documents)
        selected.flat_map { |document| document.members.empty? ? [document] : leaves(document.members) }
      end

      def unresolved_hiera_scope
        documents.each { |document| document.error('unresolved_hiera_scope') }
      end

      def yaml?(document)
        %w[.yaml .yml .json].include?(File.extname(document.path).downcase)
      end

      def select(path)
        return if @seen[path]

        @seen[path] = true
        select_entry(path, File.lstat(path))
      rescue SystemCallError, IOError, ArgumentError
        problem(path, 'unreadable_path')
      end

      def select_entry(path, stat)
        return if @puppet && stat.file? && File.extname(path) != '.pp'

        if stat.directory?
          directory(path)
        elsif stat.file?
          read(path)
        else
          problem(path, 'unsupported_file_type')
        end
      end

      def directory(path)
        entries = Dir.children(path).sort
        problem(path, 'empty_directory') if entries.empty?
        entries.each { |name| select(File.join(path, name)) }
      end

      def read(path)
        documents << @reader.read(path)
      end

      def problem(path, code)
        document = Document.new(path)
        document.error(code)
        documents << document
      end

      def scan_text(document)
        Patterns.signatures(document)
        return unless document.complete? && !yaml?(document)

        parser = @puppet || (@analysis && File.extname(document.path) == '.pp')
        (parser ? PuppetScan : TextScan).new(document).scan
      end
    end
  end
end
