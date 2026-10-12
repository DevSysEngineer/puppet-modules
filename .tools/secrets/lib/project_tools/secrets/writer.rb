# frozen_string_literal: true

require_relative 'session'
require_relative 'source_versions'
require_relative 'changes'
require_relative 'restoration'
require_relative 'transaction'
require 'open3'
require 'erb'

module ProjectTools
  module Secrets
    # Validate the entire restored final state before beginning the transaction.
    class Writer
      attr_reader :data, :candidates, :integrity

      def initialize(store, id)
        @store = store
        @id = id
        @data = store.load(id)
        @integrity = []
      end

      def apply(change)
        @store.synchronize do
          @data = @store.load(@id)
          File.open(data.fetch('root')) do |root|
            raise Failure, 'source_busy' unless root.flock(File::LOCK_EX | File::LOCK_NB)

            prepare(change)
            transact
          end
        end
      end

      def prepare(change)
        raise Failure, 'session_consumed' unless data['status'] == 'prepared'

        SourceVersions.verify(data)
        @changes = Changes.new(data, change)
        @restoration = Restoration.new(data, @changes)
        @candidates = @restoration.candidates
        @integrity = @restoration.integrity.report
        validate_candidates
        finalize_operations
      end

      def validate_candidates
        sources = candidates.to_h { |path, bytes| [@changes.source(path), bytes] }
        Scanner.complete!(Scanner.documents(sources))
        Scanner.puppet!(sources)
        sources.each { |path, bytes| syntax!(path, bytes) }
      end

      def finalize_operations
        candidates.delete_if do |path, bytes|
          file = data['files'][path]
          file && bytes == file['original']
        end
        @changes.deleted.each { |path| candidates[path] = nil }
      end

      def transact
        SourceVersions.verify(data)
        Transaction.new(@store, @id, data).apply(candidates, integrity)
      end

      def syntax!(path, bytes)
        case File.extname(path)
        when '.sh' then shell_syntax!(bytes)
        when '.json' then JSON.parse(bytes)
        when '.erb'
          raise Failure, 'invalid_template' unless Ripper.sexp(ERB.new(bytes).src)
        end
      rescue JSON::ParserError
        raise Failure, 'invalid_json'
      end

      def shell_syntax!(bytes)
        interpreter = bytes.lines.first.to_s.include?('bash') ? 'bash' : 'sh'
        _stdout, _stderr, status = Open3.capture3(interpreter, '-n', stdin_data: bytes)
        raise Failure, 'invalid_shell' unless status.success?
      end
    end
  end
end
