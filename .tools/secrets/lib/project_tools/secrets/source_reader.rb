# frozen_string_literal: true

require_relative 'document'
require_relative 'archive'
require 'securerandom'
require 'fileutils'

module ProjectTools
  module Secrets
    # Only fixed codes cross the local processing boundary.
    class Failure < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super
      end
    end

    # Reject links in every path component, including existing destination parents.
    module Paths
      def self.relative(path)
        valid = path.is_a?(String) && !path.empty? && !path.start_with?('/') &&
                path.split('/').none? { |part| ['', '.', '..', '.git'].include?(part.downcase) } &&
                !path.match?(/[\x00-\x1f\x7f\\]/)
        raise Failure, 'unsafe_path' unless valid

        path
      end

      def self.absolute(path)
        expanded = File.expand_path(path)
        current = '/'
        expanded.split('/').reject(&:empty?).each do |part|
          current = File.join(current, part)
          raise Failure, 'symlink_path' if File.symlink?(current)
        end
        expanded
      end

      def self.inside(root, path)
        absolute(File.join(root, relative(path)))
      end

      def self.within?(path, root)
        path == root || path.start_with?("#{root}/")
      end

      def self.outside_git!(path)
        current = path
        loop do
          raise Failure, 'state_inside_git' if File.exist?(File.join(current, '.git'))
          break if current == '/'

          current = File.dirname(current)
        end
      end

      def self.private_directory(path)
        raise Failure, 'destination_exists' if File.exist?(path) || File.symlink?(path)

        Dir.mkdir(absolute(path), 0o700)
      end

      def self.write_new(path, bytes, mode = 0o600)
        File.open(path, File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW, mode) do |file|
          file.write(bytes)
          file.flush
          file.fsync
        end
      end
    end

    # Read stable, bounded snapshots and delegate archive expansion without extracting files.
    class SourceReader
      def self.local_read(path)
        document = SourceReader.new.read(Paths.absolute(path))
        raise Failure, 'inspection_incomplete' unless document.complete?
        raise Failure, 'archive_write_unsupported' unless document.members.empty?

        document.text
      rescue SystemCallError, IOError
        raise Failure, 'source_unavailable'
      end

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
