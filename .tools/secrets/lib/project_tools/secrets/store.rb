# frozen_string_literal: true

require_relative 'source_reader'

module ProjectTools
  module Secrets
    # Private local state is never returned by the public service or serialized in reports.
    class Store
      VERSION = 1
      ID = /\A[0-9a-f]{32}\z/.freeze
      attr_reader :directory

      def initialize(directory)
        @directory = Paths.absolute(directory)
        verify_directory if File.exist?(@directory)
      end

      def verify_directory
        stat = File.stat(@directory)
        raise Failure, 'unsafe_state_directory' unless stat.directory? && stat.uid == Process.uid &&
                                                       stat.mode.nobits?(0o077)
      end

      def path(id)
        raise Failure, 'invalid_session' unless ID.match?(id.to_s)

        File.join(directory, "#{id}.json")
      end

      def create(data)
        Paths.outside_git!(@directory)
        FileUtils.mkdir_p(@directory, mode: 0o700)
        verify_directory
        id = SecureRandom.hex(16)
        data['format'] = VERSION
        data['status'] = 'prepared'
        Paths.write_new(path(id), JSON.generate(data))
        id
      end

      def load(id)
        file = path(id)
        self.class.private_file!(file)
        data = JSON.parse(File.read(file))
        raise Failure, 'incompatible_state' unless data['format'] == VERSION

        data
      rescue Errno::ENOENT, JSON::ParserError
        raise Failure, 'session_unavailable'
      end

      def self.private_file!(file)
        stat = File.lstat(file)
        raise Failure, 'unsafe_state_file' unless stat.file? && stat.uid == Process.uid && stat.mode.nobits?(0o077)
      end

      def save(id, data)
        temporary = "#{path(id)}.#{SecureRandom.hex(16)}"
        Paths.write_new(temporary, JSON.generate(data))
        File.rename(temporary, path(id))
        File.open(directory, &:fsync)
      ensure
        File.unlink(temporary) if temporary && File.exist?(temporary)
      end

      def synchronize
        raise Failure, 'session_unavailable' unless File.directory?(directory)

        lock = File.join(directory, 'writer.lock')
        File.open(lock, File::RDWR | File::CREAT | File::NOFOLLOW, 0o600) do |file|
          raise Failure, 'session_busy' unless file.flock(File::LOCK_EX | File::LOCK_NB)

          yield
        end
      end

      def delete(id)
        File.unlink(path(id))
      end
    end
  end
end
