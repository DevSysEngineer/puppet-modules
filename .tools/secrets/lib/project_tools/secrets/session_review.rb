# frozen_string_literal: true

require 'open3'
require_relative 'store'
require_relative 'review_output'

module ProjectTools
  module Secrets
    # Post-write review retains local value knowledge until explicit session closure.
    class SessionReview
      def initialize(store, id)
        @store = store
        @id = id
      end

      def perform(operation, options)
        @store.with_session(@id) do |data|
          @data = data
          operation == 'diff' ? diff : run(options)
        end
      end

      def diff
        ReviewOutput.new(@data).diff
      end

      def run(options)
        command = @data['policy'].fetch('commands', {}).fetch(options.fetch('command'))
        raise Failure, 'invalid_command' unless command.is_a?(Array) && command.all?(String)

        execution('run', 'executed', Open3.capture3(*command, chdir: @data['root']))
      end

      def execution(operation, status, captured)
        stdout, stderr, process = captured
        output = Redaction.new(data: @data)
        { 'operation' => operation, 'status' => status, 'complete' => true, 'exitstatus' => process.exitstatus,
          'stdout' => output.diagnostics(stdout), 'stderr' => output.diagnostics(stderr) }
      end
    end
  end
end
