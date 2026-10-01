# frozen_string_literal: true

require 'optparse'
require 'fileutils'
require 'project_tools/metadata/scanner'
require 'project_tools/shared/junit_report'

module ProjectTools
  # Explicit metadata checks and corrections, independent of manifest linting.
  module Metadata
    def self.run(arguments, output: $stdout, errors: $stderr)
      options = parse(arguments)
      findings = Scanner.new(ignore_paths: options[:ignore_paths]).findings(fix: options[:fix])
      report = Report.new(findings)
      report.print(output)
      report.write(options[:junit]) if options[:junit]
      report.status
    rescue OptionParser::ParseError, ArgumentError, SystemCallError, IOError => e
      errors.puts "metadata: #{e.message}"
      2
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
            output.puts "#{problem[:path]}:1:1: project_metadata: #{problem[:kind]}: #{problem[:message]}"
          end
        end
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
