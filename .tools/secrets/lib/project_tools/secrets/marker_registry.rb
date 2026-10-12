# frozen_string_literal: true

require_relative 'store'

module ProjectTools
  module Secrets
    # Register and clone protected occurrences while their preparation remains writable.
    class MarkerRegistry
      def initialize(store, id)
        @store = store
        @id = id
      end

      def perform(operation, options)
        @store.with_session(@id) do |data|
          @data = data
          operation == 'clone' ? clone_marker(options) : register(options.merge('operation' => operation))
        end
      end

      def destination!(path)
        raise Failure, 'unauthorized_destination' unless @data['files'].key?(path) || @data['destinations'].key?(path)
        raise Failure, 'session_consumed' unless @data['status'] == 'prepared'
      end

      def clone_marker(options)
        id, to = options.values_at('id', 'to')
        destination!(to)
        entry = @data['markers'].fetch(id).dup
        fresh = SecureRandom.hex(16)
        entry.merge!('file' => to, 'clone_of' => id)
        @data['markers'][fresh] = entry
        @store.save(@id, @data)
        { 'operation' => 'clone', 'status' => 'cloned', 'complete' => true, 'marker' => "[REDACTED-#{fresh}]" }
      end

      def register(options)
        synthetic = options['operation'] == 'fixture'
        to = options.fetch('to')
        destination!(to)
        value = synthetic ? fixture_value(to) : SourceReader.local_read(options.fetch('input'))
        fresh = SecureRandom.hex(16)
        @data['markers'][fresh] = { 'file' => to, 'raw' => JSON.generate(value), 'value' => value,
                                    'type' => 'yaml', 'replacement' => '"[REDACTED]"', 'indent' => '' }
        @store.save(@id, @data)
        { 'operation' => 'register', 'status' => 'registered', 'complete' => true, 'marker' => "[REDACTED-#{fresh}]" }
      end

      def fixture_value(to)
        raise Failure, 'fixture_destination_required' unless @data['policy'].fetch('fixture_paths', []).include?(to)

        "synthetic-#{SecureRandom.hex(16)}"
      end
    end
  end
end
