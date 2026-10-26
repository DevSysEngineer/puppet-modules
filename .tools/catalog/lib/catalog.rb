# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'rbconfig'
require 'project_tools/shared/console'
require 'project_tools/shared/junit_report'
require 'project_tools/shared/modulepath'
require_relative 'discovery'

module ProjectTools
  # Discover module-owned scenarios and compile each in an isolated Puppet process.
  class Catalog
    ROOT = File.expand_path('../../..', __dir__)
    def initialize(root: ROOT, modulepath: ENV.fetch('PROJECT_TOOLS_MODULEPATH', root), scenarios: nil,
                   console: $stdout, errors: $stderr)
      @modulepath_input = modulepath
      @scenarios = scenarios
      @console = Shared::Console.new('Puppet catalogs', output: console, scope: 'Module catalog scenarios')
      @errors = errors
      @results = []
    end

    def run(report: nil)
      @console.during { execute(report) }
    rescue SystemCallError, IOError => e
      @console.diagnostic("Cannot write catalog JUnit report: #{e.message}", output: @errors)
      finish(error: e.message)
      1
    end

    def execute(report)
      return invalid_report if report && !report.end_with?('.xml')

      select_scenarios
      compile_all
      write_report(report) if report
      finish(report: report)
      @results.any? { |result| result[:kind] } ? 1 : 0
    end

    def select_scenarios
      @modulepath = Shared::Modulepath.parse(@modulepath_input)
      return if @scenarios

      discovery = Discovery.new(@modulepath)
      @scenarios = discovery.scenarios
      @results.concat(discovery.errors)
      @skipped = discovery.skipped
    rescue ArgumentError, SystemCallError => e
      @scenarios = []
      @results << { name: 'Scenario selection', kind: :error, message: e.message }
    end

    def invalid_report
      @console.finish(status: 'ERROR', execution: 'not executed', details: ['Expected a JUnit path ending in .xml.'])
      1
    end

    def compile_all
      if @scenarios.empty? && @results.empty?
        @results << { name: 'Scenario selection', kind: :error, message: 'No catalog scenarios selected.' }
      end
      @scenarios.each do |scenario|
        result = compile(scenario)
        @results << result
        @console.finding("#{result[:name]}: #{result[:message]}") unless result[:message].empty?
        @console.advance(unit: 'scenarios', total: @scenarios.size)
      end
    end

    def compile(scenario)
      output, status = Open3.capture2e(RbConfig.ruby, File.join(__dir__, 'worker.rb'),
                                       @modulepath.join(File::PATH_SEPARATOR),
                                       scenario.fetch(:manifest), scenario.fetch(:facts))
      kind = status.success? ? nil : :error
      kind = :failure if status.exitstatus == 1
      output = "Compiler process ended: #{status}" if output.empty? && kind
      { name: scenario.fetch(:name), kind: kind, message: output }
    rescue SystemCallError => e
      { name: scenario.fetch(:name), kind: :error, message: "Cannot start compiler: #{e.message}" }
    end

    def counts
      { tests: @results.size, failures: @results.count { |result| result[:kind] == :failure },
        errors: @results.count { |result| result[:kind] == :error } }
    end

    def finish(report: nil, error: nil)
      incomplete = error || counts[:errors].positive?
      outcome = counts[:failures].positive? ? 'FAILED' : 'PASSED'
      @console.finish(status: incomplete ? 'ERROR' : outcome, execution: incomplete ? 'incomplete' : 'complete',
                      facts: facts, details: diagnostics + Array(error), report: report)
    end

    def facts
      details = ["Scenarios: #{@scenarios.size} selected | #{counts[:tests] - counts[:errors]} checked",
                 "Results: #{counts[:failures]} failures | #{counts[:errors]} errors"]
      details << "Modules without tests: #{@skipped.size} skipped" if @skipped
      details
    end

    def diagnostics
      @results.filter_map { |result| "#{result[:name]}: #{result[:message]}" if result[:kind] }
    end

    def write_report(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |output|
        Shared::JunitReport.write(output, name: 'catalog', **counts) do |xml|
          @results.each { |result| write_case(xml, result) }
        end
      end
    end

    def write_case(xml, result)
      xml.testcase(classname: 'catalog', name: result[:name]) do
        if result[:kind]
          type = result[:kind] == :failure ? 'CatalogFailure' : 'CompilerError'
          xml.tag!(result[:kind], result[:message], type: type)
        elsif !result[:message].empty?
          xml.tag!('system-out', result[:message])
        end
      end
    end
  end
end
