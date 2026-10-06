# frozen_string_literal: true

require 'optparse'
require 'fileutils'
require 'project_tools/metadata/scanner'
require 'project_tools/shared/junit_report'
require 'project_tools/shared/console'

module ProjectTools
  # Explicit metadata checks and corrections, independent of manifest linting.
  module Metadata
    def self.run(arguments, output: $stdout, errors: $stderr)
      console = Shared::Console.new('Metadata', output: output, scope: 'root metadata and selected own modules')
      console.during do
        execute(arguments, console, errors)
      end
    end

    def self.execute(arguments, console, errors)
      options = parse(arguments)
      scanner = Scanner.new(ignore_paths: options[:ignore_paths])
      report = scan(scanner, options, console)
      report.write(options[:junit]) if options[:junit]
      report.finish(console, report: options[:junit])
      report.status
    rescue OptionParser::ParseError, ArgumentError, SystemCallError, IOError => e
      console.diagnostic("metadata: #{e.message}", output: errors)
      Report.new(scanner&.results || {}).finish(console, error: e.message)
      2
    end

    def self.scan(scanner, options, console)
      findings = scanner.findings(fix: options[:fix]) do |problem|
        console.finding(Report.diagnostic(problem))
        console.advance(unit: 'findings')
      end
      Report.new(findings)
    end

    def self.parse(arguments)
      options = { fix: false, ignore_paths: [] }
      parser = OptionParser.new do |cli|
        cli.banner = 'Usage: project-tools-metadata [--fix] [--ignore-paths GLOBS] [--junit REPORT.xml]'
        cli.on('--fix', 'Synchronize known names and versions') { options[:fix] = true }
        cli.on('--ignore-paths GLOBS', Array, 'Exclude metadata globs') { |paths| options[:ignore_paths] = paths }
        cli.on('--junit REPORT.xml', 'Also write a JUnit report') { |path| options[:junit] = path }
      end
      raise ArgumentError, parser.to_s unless parser.parse(arguments).empty?
      raise ArgumentError, 'JUnit report path must not be empty' if options[:junit] == ''

      options
    end

    # One case per selected file or configuration source, including clean files.
    class Report
      def initialize(findings)
        @findings = findings
      end

      def print(output)
        @findings.each_value do |problems|
          problems.each do |problem|
            output.puts self.class.diagnostic(problem)
          end
        end
      end

      def self.diagnostic(problem)
        source = problem[:path].end_with?('metadata.json') ? "#{problem[:path]}:1:1" : problem[:path]
        "#{source}: project_metadata: #{problem[:kind]}: #{problem[:message]}"
      end

      def finish(console, report: nil, error: nil)
        outcome = status.zero? ? 'PASSED' : 'FAILED'
        incomplete = error || @findings.key?('configuration') || @findings.key?('VERSION')
        console.finish(status: error ? 'ERROR' : outcome, execution: incomplete ? 'incomplete' : 'complete',
                       facts: facts, details: problems.map { |problem| self.class.diagnostic(problem) } + Array(error),
                       report: report)
      end

      def problems
        @findings.sort.flat_map { |_path, entries| entries.sort_by { |entry| entry[:message] } }
      end

      def facts
        return ['Sources: selection not evaluated'] if @findings.empty?

        counts = problems.group_by { |problem| problem[:kind] }
        [selection, "Sources: #{@findings.size} selected | #{failures} with blocking findings",
         "Findings: #{counts.fetch(:error, []).size} blocking | #{counts.fetch(:fixed, []).size} fixed"]
      end

      def selection
        return 'Own module metadata selection: incomplete' if @findings.key?('configuration')

        modules = @findings.keys.count { |path| path != 'metadata.json' && path.end_with?('/metadata.json') }
        "Own module metadata: #{modules} selected"
      end

      def write(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'w') do |output|
          Shared::JunitReport.write(output, name: 'metadata', tests: @findings.size,
                                            failures: failures, errors: 0) do |xml|
            @findings.each { |file, problems| write_case(xml, file, problems) }
          end
        end
      end

      def failures
        @findings.count { |_file, problems| problems.any? { |problem| problem[:kind] == :error } }
      end

      def status
        failures.positive? ? 1 : 0
      end

      def write_case(xml, file, problems)
        xml.testcase(classname: 'metadata', name: file) do
          remaining = messages(problems, :error)
          xml.failure(remaining, type: 'MetadataError') unless remaining.empty?
          fixes = messages(problems, :fixed)
          xml.tag!('system-out', fixes) unless fixes.empty?
        end
      end

      def messages(problems, kind)
        problems.filter_map { |problem| problem[:message] if problem[:kind] == kind }.join("\n")
      end
    end
  end
end
