# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'stringio'
require_relative 'session'
require_relative 'review_output'

module ProjectTools
  module Secrets
    # Post-write review retains local value knowledge until explicit session closure.
    class SessionReview
      def initialize(store, id)
        @store = store
        @id = id
        @data = store.load(id)
      end

      OPERATIONS = { 'diff' => :diff, 'run' => :run, 'clone' => :clone_marker,
                     'register' => :register, 'fixture' => :register, 'close' => :close,
                     'cancel' => :close, 'recover' => :recover }.freeze

      def perform(operation, options)
        method = OPERATIONS.fetch(operation) { raise Failure, 'unknown_operation' }
        @store.synchronize do
          @data = @store.load(@id)
          public_send(method, options.merge('operation' => operation))
        end
      end

      def diff(_options)
        ReviewOutput.new(@data).diff
      end

      def run(options)
        command = @data['policy'].fetch('commands', {}).fetch(options.fetch('command'))
        raise Failure, 'invalid_command' unless command.is_a?(Array) && command.all?(String)

        execution('run', 'executed', Open3.capture3(*command, chdir: @data['root']))
      end

      def execution(operation, status, captured)
        stdout, stderr, process = captured
        output = ReviewOutput.new(@data)
        { 'operation' => operation, 'status' => status, 'complete' => true, 'exitstatus' => process.exitstatus,
          'stdout' => output.safe_text(stdout), 'stderr' => output.safe_text(stderr) }
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

      def close(options)
        operation = options.fetch('operation')
        raise Failure, 'recovery_required' if %w[writing recovery_required].include?(@data['status'])

        @store.delete(@id)
        { 'operation' => operation, 'status' => operation == 'close' ? 'closed' : 'cancelled', 'complete' => true }
      end

      def recover(_options)
        raise Failure, 'recovery_not_required' unless %w[writing recovery_required].include?(@data['status'])

        File.open(@data['root']) do |root|
          raise Failure, 'source_busy' unless root.flock(File::LOCK_EX | File::LOCK_NB)

          Transaction.new(@store, @id, @data).recover
        end
      end
    end
  end
end
