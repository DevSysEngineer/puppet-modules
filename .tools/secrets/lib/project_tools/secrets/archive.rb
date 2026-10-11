# frozen_string_literal: true

require 'stringio'
require 'zlib'
require 'rubygems/package'
require_relative 'tar_archive'

module ProjectTools
  module Secrets
    # Archives stay in memory: no paths, links or executables are materialized.
    class Archive
      include TarArchive

      MAX_EXPANDED = 25 * 1024 * 1024
      MAX_MEMBERS = 1000
      MAX_DEPTH = 3

      def initialize
        @expanded = 0
        @members = 0
      end

      def self.supported?(path)
        path.match?(/\.(?:tar|gz|tgz)\z/i)
      end

      def unpack(document, bytes, depth:, &block)
        return document.error('archive_depth_limit') if depth >= MAX_DEPTH

        document.coverage = 'archive'
        document.path.match?(/\.(?:gz|tgz)\z/i) ? gzip(document, bytes, &block) : tar(document, bytes, &block)
      rescue StandardError
        document.error('invalid_archive')
      end

      def account(size)
        @expanded += size
        raise ArgumentError if @expanded > MAX_EXPANDED
      end

      def member(document, name, bytes)
        count_member
        raise ArgumentError if bytes.bytesize > Scanner::MAX_BYTES

        child = yield(name, bytes)
        document.members << child
      end

      def count_member
        @members += 1
        raise ArgumentError if @members > MAX_MEMBERS
      end

      def gzip(document, bytes, &block)
        stream = Zlib::GzipReader.new(StringIO.new(bytes))
        expanded = expand_gzip(stream)
        raise ArgumentError unless stream.unused.to_s.empty?

        name = document.path.sub(/\.tgz\z/i, '.tar').sub(/\.gz\z/i, '')
        member(document, name, expanded, &block)
      ensure
        stream&.close
      end

      def expand_gzip(stream)
        expanded = +''.b
        until stream.eof?
          chunk = stream.read(16_384)
          account(chunk.bytesize)
          expanded << chunk
          raise ArgumentError if expanded.bytesize > Scanner::MAX_BYTES
        end
        expanded
      end
    end
  end
end
