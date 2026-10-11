# frozen_string_literal: true

require 'optparse'
require 'project_tools/shared/console'
require_relative 'secrets/scanner'
require_relative 'secrets/output'

module ProjectTools
  # Local inspection gate. Findings remain findings after a redacted copy is made.
  module Secrets
    def self.run(arguments, output: $stdout)
      Command.new(output).run(arguments)
    end

    # Parse options and keep all error reporting independent of input values.
    class Command
      CODES = { 'no_findings' => 0, 'findings' => 1, 'incomplete' => 2 }.freeze
      STATES = { 'no_findings' => 'PASSED', 'findings' => 'FAILED', 'incomplete' => 'ERROR' }.freeze

      def initialize(output)
        @output = output
        @options = {}
        @scanner = Scanner.new
        @errors = []
        @report_written = false
      end

      def parser
        OptionParser.new do |options|
          options.banner = 'Usage: project-tools-secrets [--redact NEW_DIR] [--json] [--junit NEW_FILE] PATH ...'
          options.on('--redact NEW_DIR', 'Write separate sanitized copies') { |dir| @options[:redact] = dir }
          options.on('--json', 'Print metadata only as JSON') { @options[:json] = true }
          options.on('--puppet', 'Check hardcoded values in Puppet manifests (requires OpenVox)') do
            @options[:puppet] = true
          end
          options.on('--junit NEW_FILE', 'Also write metadata as JUnit XML') { |path| @options[:junit] = path }
          options.on('-h', '--help', 'Show usage') { @options[:help] = true }
        end
      end

      def run(arguments)
        paths = arguments.dup
        parser.parse!(paths)
        return help if @options[:help]
        raise OptionParser::MissingArgument if paths.empty?

        @scanner = Scanner.new(puppet: @options[:puppet])
        @writer = Output.new(@scanner.documents, paths)
        execute(paths)
      rescue OptionParser::ParseError, ArgumentError
        @errors << 'invalid_arguments_or_destination'
        finish
      end

      def help
        @output.puts parser
        0
      end

      def execute(paths)
        return inspect_sources(paths) if @options[:json]

        @console = Shared::Console.new('Sensitive data scan', output: @output, scope: "#{paths.length} input paths")
        @console.during { inspect_sources(paths) }
      end

      def inspect_sources(paths)
        perform_scan(paths)
        finish
      end

      def perform_scan(paths)
        @scanner.scan(paths)
        redact if @options[:redact]
        write_report if @options[:junit]
      rescue StandardError, SystemStackError, SignalException
        @errors << 'execution_failed'
      end

      def redact
        if @scanner.documents.all?(&:complete?)
          @writer.redact(@options[:redact])
        else
          @errors << 'redaction_withheld'
        end
      end

      def write_report
        @writer.junit(@options[:junit])
        @report_written = true
      rescue StandardError
        @errors << 'report_write_failed'
      end

      def classification(records)
        return 'incomplete' unless @errors.empty? && records.all? { |record| record[:complete] }

        records.any? { |record| !record[:findings].empty? } ? 'findings' : 'no_findings'
      end

      def result
        records = @writer ? @writer.records : []
        status = classification(records)
        { status: status, complete: status != 'incomplete', files: records, errors: @errors,
          report_written: @report_written }
      end

      def finish
        data = result
        @options[:json] ? @output.puts(JSON.generate(data)) : console_result(data)
        CODES.fetch(data[:status])
      end

      def console_result(data)
        console = @console || Shared::Console.new('Sensitive data scan', output: @output)
        details = @writer ? @writer.console_details : []
        console.finish(status: STATES.fetch(data[:status]), execution: data[:complete] ? 'complete' : 'incomplete',
                       facts: ["Result: #{data[:status]}", "Files: #{data[:files].length}",
                               'No findings means no matches in these checks, not a safety guarantee.'],
                       details: details + data[:errors], report: @report_written ? '[requested report]' : nil)
      end
    end
  end
end
