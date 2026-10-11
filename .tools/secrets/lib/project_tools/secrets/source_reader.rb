# frozen_string_literal: true

require_relative 'document'
require_relative 'archive'

module ProjectTools
  module Secrets
    # Read stable, bounded snapshots and delegate archive expansion without extracting files.
    class SourceReader
      MAX_BYTES = 5 * 1024 * 1024

      def initialize
        @archive = Archive.new
      end

      def read(path)
        document = Document.new(path)
        text = File.open(path, File::RDONLY | File::NOFOLLOW | File::NONBLOCK) { |file| snapshot(file, document) }
        return document unless text

        inspect_bytes(path, text)
      end

      def inspect_bytes(path, text, depth: 0)
        if Archive.supported?(path)
          archive_document(path, text, depth)
        else
          text_document(path, text.force_encoding(Encoding::UTF_8))
        end
      end

      def archive_document(path, text, depth)
        document = Document.new(path)
        @archive.unpack(document, text, depth: depth) do |name, bytes|
          inspect_bytes(name, bytes, depth: depth + 1)
        end
        document
      end

      def text_document(path, text)
        code = content_error(text)
        document = Document.new(path, code ? '' : text)
        document.error(code) if code
        document
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
    end
  end
end
