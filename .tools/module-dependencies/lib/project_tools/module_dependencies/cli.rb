# frozen_string_literal: true

require 'fileutils'
require 'optparse'
require 'project_tools/shared/modulepath'
require 'project_tools/module_dependencies/result'
require 'project_tools/module_dependencies/reporter'

module ProjectTools
  module ModuleDependencies
    # Run the native scan with console output and an explicitly requested report.
    class Cli
      def self.run(arguments, console: $stdout, errors: $stderr)
        new(console, errors).run(arguments)
      end

      def initialize(console, errors)
        @root = Dir.pwd
        @console = console
        @errors = errors
      end

      def run(arguments)
        result = parse(arguments)
        prepare_report if @report
        result ||= scan
        write(result) if @report
        Reporter.new(result, @root).console(@console, @errors)
        result.status
      rescue SystemCallError, IOError => e
        @errors.puts "Cannot write Puppet dependency JUnit report (#{e.class})."
        2
      end

      def prepare_report
        result = Result.new
        result.error(:incomplete_scan, 'Dependency scan has not completed.')
        FileUtils.mkdir_p(File.dirname(@report))
        write(result)
      end

      def parse(arguments)
        cli = parser
        raise OptionParser::InvalidArgument, cli.to_s unless cli.parse(arguments).empty?

        nil
      rescue OptionParser::ParseError => e
        result = Result.new
        result.error(:configuration_error, e.message)
        result
      end

      def parser
        OptionParser.new do |cli|
          cli.banner = 'Usage: project-tools-module-dependencies [--junit REPORT.xml]'
          cli.on('--junit REPORT.xml', 'Also write a JUnit report') do |path|
            raise OptionParser::InvalidArgument, 'JUnit report must end in .xml' unless path.end_with?('.xml')

            @report = File.expand_path(path)
          end
        end
      end

      def write(result)
        File.open(@report, 'w') { |output| Reporter.new(result, @root).write(output) }
      end

      def scan
        result = Result.new
        perform_scan(result)
        result
      rescue ArgumentError => e
        result.error(:configuration_error, e.message)
        result
      rescue StandardError, LoadError => e
        result.error(:runtime_error, "Dependency scan failed (#{e.class}).")
        result
      end

      def perform_scan(result)
        paths = ProjectTools::Shared::Modulepath.parse(ENV.fetch('PROJECT_TOOLS_MODULEPATH', nil))
        require 'project_tools/module_dependencies/openvox_adapter'
        require 'project_tools/module_dependencies/root_dependencies'
        root = RootDependencies.new(@root, result)
        root.read
        OpenvoxAdapter.new(paths, result).scan { |environment| root.check(environment) }
        result.error(:empty_scan, 'No usable module metadata was assessed.') if result.assessed.empty?
      end
    end
  end
end
