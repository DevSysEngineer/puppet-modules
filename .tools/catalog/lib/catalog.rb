# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'project_tools/shared/console'
require 'project_tools/shared/modulepath'
require_relative 'reporting'
require_relative 'worker_result'

module ProjectTools
  # Discover module-owned scenarios and compile each in an isolated Puppet process.
  class Catalog
    include Reporting

    ROOT = File.expand_path('../../..', __dir__)
    def initialize(root: ROOT, modulepath: ENV.fetch('PROJECT_TOOLS_MODULEPATH', root), scenarios: nil,
                   console: $stdout, errors: $stderr)
      @modulepath_input = modulepath
      @scenarios = scenarios
      software = { tool: 'project-tools-catalog', runtime: true, version: File.read(File.join(ROOT, 'VERSION')).strip }
      @console = Shared::Console.new('Puppet catalogs', output: console, scope: 'Module catalog scenarios',
                                                        software: software)
      @errors = errors
      @results = []
    end

    def run(report: nil)
      @console.during { execute(report) }
    end

    def execute(report)
      return invalid_report if report && !report.end_with?('.xml')

      File.unlink(report) if report && File.exist?(report)
      complete(report)
    rescue SignalException => e
      execution_error("Catalog execution interrupted: #{e.class}")
      raise
    rescue StandardError => e
      execution_error("Cannot complete catalog check: #{e.message}")
      1
    end

    def complete(report)
      select_scenarios
      compile_all
      write_report(report) if report
      finish(report: report)
      @results.any? { |result| result[:kind] } ? 1 : 0
    end

    def select_scenarios
      @modulepath = Shared::Modulepath.parse(@modulepath_input)
      return if @scenarios

      require_relative 'discovery'
      discovery = Discovery.new(@modulepath)
      @scenarios = discovery.scenarios
      @results.concat(discovery.errors)
      @skipped = discovery.skipped
    rescue ArgumentError, SystemCallError, Shared::PuppetRuntime::Error => e
      @scenarios = []
      @results << { name: 'Scenario selection', kind: :error, message: e.message }
    end

    def compile_all
      if @scenarios.empty? && @results.empty?
        @results << { name: 'Scenario selection', kind: :error, message: 'No catalog scenarios selected.' }
      end
      @results.each { |result| present(result) }
      @scenarios.each do |scenario|
        result = compile(scenario)
        @results << result
        present(result)
        @console.advance(unit: 'scenarios', total: @scenarios.size)
      end
    end

    def compile(scenario)
      arguments = worker_arguments(scenario)
      output, diagnostics, status = Open3.capture3(RbConfig.ruby, File.join(__dir__, 'worker.rb'), *arguments)
      worker_result(scenario, output, diagnostics, status)
    rescue SystemCallError => e
      { name: scenario.fetch(:name), kind: :error, message: "Cannot start compiler: #{e.message}" }
    end

    def worker_result(scenario, output, diagnostics, status)
      WorkerResult.new(scenario.fetch(:name), output, diagnostics, status).result
    end

    def worker_arguments(scenario)
      [@modulepath.join(File::PATH_SEPARATOR), *scenario.values_at(:manifest, :facts),
       scenario[:module_directory].to_s, scenario[:hiera].to_s]
    end

    def counts
      { tests: @results.size, failures: @results.count { |result| result[:kind] == :failure },
        errors: @results.count { |result| result[:kind] == :error } }
    end

    def finish(report: nil, error: nil)
      incomplete = error || counts[:errors].positive?
      outcome = counts[:failures].positive? ? 'FAILED' : 'PASSED'
      @console.finish(status: incomplete ? 'ERROR' : outcome, execution: incomplete ? 'incomplete' : 'complete',
                      facts: facts(error: error), details: summary_details(error), report: report)
    end

    def facts(error: nil)
      selected = @scenarios ? @scenarios.size : 'unknown'
      details = ["Scenarios: #{selected} selected | #{counts[:tests] - counts[:errors]} checked",
                 "Results: #{counts[:failures]} failures | #{counts[:errors] + (error ? 1 : 0)} errors"]
      details << "Modules without tests: #{@skipped.size} skipped" if @skipped
      details
    end

    def execution_error(message)
      @has_findings = true
      @console.finding('Execution error')
      @console.diagnostic(message, output: @errors)
      finish(error: message)
    end
  end
end
