# frozen_string_literal: true

require 'optparse'
require_relative 'command_options'
require_relative 'writer'
require_relative 'session_review'

module ProjectTools
  module Secrets
    # Both executables use the same session API and metadata-only failure boundary.
    class SessionCommand
      include CommandOptions

      def initialize(output)
        @output = output
        @options = {}
      end

      def run(arguments)
        $DEBUG = false
        parse(arguments)
        return help if @options['help']

        emit_result(execute)
      rescue Failure => e
        failure('refused', e.code)
        emit
      rescue StandardError, LoadError, SystemStackError, SignalException
        failure('error', 'operation_failed')
        emit
      end

      def emit_result(result)
        @result = result
        emit
      end

      def failure(status, code)
        @result = { 'operation' => @operation, 'status' => status, 'complete' => false, 'errors' => [code] }
      end

      def parse(arguments)
        args = arguments.dup
        @operation = args.shift
        session_parser.parse!(args)
        raise Failure, 'unexpected_arguments' unless args.empty?
      end

      def help
        @output.puts(session_parser)
        0
      end

      def execute
        store = Store.new(@options.fetch('state'))
        return prepare(store) if @operation == 'prepare'

        id = @options.fetch('session')
        if @operation == 'apply'
          return Writer.new(store,
                            id).apply(JSON.parse(SourceReader.local_read(@options.fetch('changes'))))
        end

        SessionReview.new(store, id).perform(@operation, @options)
      end

      def prepare(store)
        Session.new(root: @options.fetch('root'), policy: @options.fetch('policy'),
                    tree: @options.fetch('tree'), store: store).prepare
      end

      def emit
        write_report if @options['junit']
        @output.puts(JSON.generate(@result))
        exitstatus
      rescue IOError, SystemCallError
        withdraw_preparation
        2
      end

      def exitstatus
        return 2 unless @result['complete']
        return @result['exitstatus'] || 2 if @result['status'] == 'executed'
        if %w[applied closed cancelled registered cloned reviewed recovered no_findings].include?(@result['status'])
          return 0
        end
        return 1 if @result['status'] == 'findings'

        2
      end

      def write_report
        path = @options['junit']
        Paths.absolute(path)
        Paths.write_new(path, Output.session_xml(@result, @operation))
      rescue StandardError
        @result['report_error'] = 'report_write_failed'
        @result['complete'] = false
        withdraw_preparation
      end

      def withdraw_preparation
        return unless @operation == 'prepare' && @result['prepared']

        store = Store.new(@options.fetch('state'))
        data = store.load(@result.fetch('session'))
        FileUtils.remove_entry(data['tree'])
        store.delete(@result.delete('session'))
        @result.merge!('prepared' => false, 'files' => [], 'status' => 'incomplete', 'complete' => false)
      end
    end
  end
end
