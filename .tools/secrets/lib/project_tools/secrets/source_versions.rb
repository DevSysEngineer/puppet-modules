# frozen_string_literal: true

require_relative 'source_reader'

module ProjectTools
  module Secrets
    # Selected sources and context share the same conflict boundary.
    module SourceVersions
      def self.verify(data)
        verify_policy(data)
        data['files'].each_value { |file| verify_file(data['root'], file) }
        verify_absent(data)
      end

      def self.verify_policy(data)
        raise Failure, 'context_conflict' unless SourceReader.local_read(data['policy_path']) == data['policy_bytes']
      end

      def self.verify_absent(data)
        data['destinations'].each_value do |file|
          relative = file['source']
          raise Failure, 'destination_conflict' if File.exist?(Paths.inside(data['root'], relative))
        end
      end

      def self.verify_file(root, file)
        path = Paths.inside(root, file['source'])
        raise Failure, 'source_conflict' unless SourceReader.local_read(path) == file['original']

        stat = File.stat(path)
        raise Failure, 'metadata_conflict' unless [stat.mode & 0o7777, stat.uid, stat.gid] ==
                                                  file.values_at('mode', 'uid', 'gid')
        raise Failure, 'source_conflict' unless identity(path) == file['identity']
      end

      def self.identity(path)
        stat = File.stat(path)
        [stat.dev, stat.ino, stat.mode, stat.uid, stat.gid, stat.mtime.to_r.to_s]
      end
    end
  end
end
