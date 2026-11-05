# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'project_tools/shared/console'
require 'project_tools/shared/modulepath'
require_relative 'reporting'
require_relative 'compilation'
require_relative 'summary'
require_relative 'worker_result'

module ProjectTools
  # Discover module-owned scenarios and compile each in an isolated Puppet process.
  class Catalog
    include Reporting
    include Compilation
    include Summary

    ROOT = File.expand_path('../../..', __dir__)
    def initialize(root: ROOT, modulepath: ENV.fetch('PROJECT_TOOLS_MODULEPATH', root), scenarios: nil,
                   jobs: 1, **output)
      @jobs = Shared::WorkerCount.parse(jobs)
      @modulepath_input = modulepath
      @scenarios = scenarios
      prepare_console(**output)
      @results = []
      @processed = 0
    end

    def prepare_console(console: $stdout, errors: $stderr)
      software = { tool: 'project-tools-catalog', runtime: true, version: File.read(File.join(ROOT, 'VERSION')).strip }
      @console = Shared::Console.new('Puppet catalogs', output: console, scope: 'Module catalog scenarios',
                                                        software: software)
      @errors = errors
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
      counts.values_at(:failures, :errors).any?(&:positive?) ? 1 : 0
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
      compile_scenarios
    end

    def record(result)
      @results << result
      @processed += 1
      present(result)
      @console.advance(unit: 'scenarios', total: @scenarios.size)
    end

    def finish(report: nil, error: nil)
      incomplete = error || counts[:errors].positive? || cycle_skips.positive?
      @console.finish(status: outcome(error), execution: incomplete ? 'incomplete' : 'complete',
                      facts: facts(error: error), report: report)
    end

    def execution_error(message)
      @console.finding("Execution error\n#{message}", output: @errors)
      finish(error: message)
    end
  end
end
