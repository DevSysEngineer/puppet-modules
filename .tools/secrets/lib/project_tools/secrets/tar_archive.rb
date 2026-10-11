# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Reject unsafe tar headers and read regular members without extraction.
    module TarArchive
      def tar(document, bytes, &block)
        raise ArgumentError unless (bytes.bytesize % 512).zero? && bytes.end_with?("\0" * 1024)

        stream = StringIO.new(bytes)
        seen = {}
        each_tar_entry(stream, bytes) do |entry, header|
          tar_entry(document, entry, header, seen, &block)
        end
        raise ArgumentError unless stream.read.match?(/\A\x00*\z/) && !document.members.empty?
      end

      def each_tar_entry(stream, bytes)
        Gem::Package::TarReader.new(stream) do |archive|
          archive.each do |entry|
            yield entry, bytes.byteslice(stream.pos - 512, 512)
          end
        end
      end

      def tar_entry(document, entry, header, seen, &block)
        validate_checksum(header)
        unique_name(entry.full_name, seen)
        size = entry.header.size
        raise ArgumentError unless entry.file? || (entry.directory? && size.zero?)
        return count_member if entry.directory?

        member(document, entry.full_name, tar_data(entry), &block)
      end

      def unique_name(name, seen)
        validate_name(name)
        raise ArgumentError if seen[name]

        seen[name] = true
      end

      def tar_data(entry)
        account(entry.header.size)
        raise ArgumentError if entry.header.size > Scanner::MAX_BYTES

        data = entry.read
        raise ArgumentError unless data.bytesize == entry.header.size

        data
      end

      def validate_checksum(header)
        field = header.byteslice(148, 8)
        checksum = field.delete("\0 ")
        raise ArgumentError unless checksum.match?(/\A[0-7]+\z/)
        raise ArgumentError unless header.bytes.sum - field.bytes.sum + (8 * 32) == checksum.to_i(8)
      end

      def validate_name(name)
        name = name.dup.force_encoding(Encoding::UTF_8)
        raise ArgumentError unless name.valid_encoding?
        raise ArgumentError if name.empty? || name.start_with?('/') || name.match?(/[[:cntrl:]\\:]/)
        raise ArgumentError if name.split('/').any? { |part| ['.', '..', ''].include?(part) }
      end
    end
  end
end
