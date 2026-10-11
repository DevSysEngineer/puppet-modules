# frozen_string_literal: true

require_relative 'document'
require_relative 'text_scan'
require_relative 'yaml_scan'
require_relative 'puppet_scan'

module ProjectTools
  module Secrets
    # Selection includes hidden files; skipped or unreadable sources are errors.
    class Scanner
      MAX_BYTES = 5 * 1024 * 1024
      attr_reader :documents

      def initialize(puppet: false)
        @documents = []
        @seen = {}
        @puppet = puppet
      end

      def scan(paths)
        select_paths(paths)
        scan_yaml
        documents.each { |document| scan_text(document) }
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
        documents.select { |doc| doc.complete? && yaml?(doc) }
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
        document = Document.new(path)
        text = File.open(path, File::RDONLY | File::NOFOLLOW | File::NONBLOCK) { |file| snapshot(file, document) }
        return documents << document unless text

        text.force_encoding(Encoding::UTF_8)
        code = content_error(text)
        code ? problem(path, code) : documents << Document.new(path, text)
      end

      def snapshot(file, document)
        return document.error('unsupported_file_type') unless file.stat.file?
        return document.error('file_too_large') if file.stat.size > MAX_BYTES

        before = stamp(file)
        data = file.read(MAX_BYTES + 1)
        return document.error('source_changed') unless before == stamp(file)

        data
      end

      def stamp(file)
        stat = file.stat
        [stat.size, stat.mtime, stat.ctime]
      end

      def content_error(text)
        return 'file_too_large' if text.bytesize > MAX_BYTES
        return 'unsupported_encoding' unless text.valid_encoding?
        return 'binary_content' if text.match?(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/)

        nil
      end

      def problem(path, code)
        document = Document.new(path)
        document.error(code)
        documents << document
      end

      def scan_text(document)
        Patterns.signatures(document)
        return unless document.complete? && !yaml?(document)

        (@puppet ? PuppetScan : TextScan).new(document).scan
      end
    end
  end
end
