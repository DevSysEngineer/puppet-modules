# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'project_tools/shared/junit_report'
require 'project_tools/shared/console'

module ProjectTools
  # Runs the native validator once per manifest and reports every result, including failures.
  class Validate
    def initialize(paths, console)
      @paths = paths.map { |path| Pathname.new(File.expand_path(path)).relative_path_from(Pathname.pwd).to_s }.uniq
      @console = Shared::Console.new('Puppet validation', output: console, scope: "#{@paths.size} files selected")
      @results = []
    end

    def self.run(arguments, console: $stdout, errors: $stderr)
      report, *paths = arguments
      return usage(console, errors) unless report&.end_with?('.xml')

      new(paths, console).run(report, errors)
    end

    def self.usage(console, errors)
      errors.puts 'Usage: validate-junit REPORT.xml MANIFEST.pp [MANIFEST.pp ...]'
      Shared::Console.new('Puppet validation', output: console)
                     .finish(status: 'ERROR', execution: 'not executed', details: ['Invalid arguments; see usage.'])
      1
    end

    def run(report, errors)
      @console.during { execute(report, errors) }
    end

    def execute(report, errors)
      FileUtils.mkdir_p(File.dirname(report))
      status = File.open(report, 'w') { |output| write(output) }
      finish(report: report)
      status
    rescue SystemCallError, IOError => e
      message = "Cannot write Puppet validation JUnit report: #{e.message}"
      @console.diagnostic(message, output: errors)
      finish(error: message)
      1
    end

    def write(output)
      results = validation_results
      counts = result_counts(results)
      Shared::JunitReport.write(output, name: 'validate', **counts) do |xml|
        results.each { |result| write_case(xml, result) }
      end
      counts.values_at(:failures, :errors).all?(&:zero?) ? 0 : 1
    end

    def validation_results
      if @paths.empty?
        @results << { path: 'Manifest selection', kind: :error, message: 'No Puppet manifests selected.' }
      else
        @paths.each { |path| process(path) }
      end
      @results
    end

    def process(path)
      result = validate(path)
      @results << result
      @console.finding(diagnostic(result)) unless result[:message].empty?
      @console.advance(unit: 'files', total: @paths.size)
    end

    def finish(report: nil, error: nil)
      counts = result_counts(@results)
      incomplete = error || counts[:errors].positive?
      outcome = counts[:failures].positive? ? 'FAILED' : 'PASSED'
      @console.finish(status: incomplete ? 'ERROR' : outcome, execution: incomplete ? 'incomplete' : 'complete',
                      facts: facts(counts), details: diagnostics + Array(error), report: report)
    end

    def facts(counts)
      ["Files: #{@paths.size} selected | #{@results.count { |r| r[:kind] != :error }} checked",
       "Results: #{counts[:failures]} failures | #{counts[:errors]} errors"]
    end

    def diagnostics
      @results.sort_by { |r| r[:path] }.filter_map { |result| diagnostic(result) unless result[:message].empty? }
    end

    def diagnostic(result)
      "#{result[:path]}: #{result[:kind] || 'native diagnostic'}\n#{result[:message]}"
    end

    def result_counts(results)
      { tests: results.length, failures: results.count { |r| r[:kind] == :failure },
        errors: results.count { |r| r[:kind] == :error } }
    end

    def validate(path)
      unless path.end_with?('.pp') && File.file?(path)
        return { path: path, kind: :error, message: "Expected an existing .pp file: #{path}" }
      end

      # The active bundle supplies the executable and Ruby; no shell interprets manifest paths.
      output, status = Open3.capture2e(RbConfig.ruby, Gem.bin_path('openvox', 'puppet'),
                                       'parser', 'validate', '--color=false', File.expand_path(path))
      validation_result(path, output, status)
    rescue SystemCallError => e
      { path: path, kind: :error, message: "Cannot start Puppet validator: #{e.message}" }
    end

    def validation_result(path, output, status)
      kind = status.success? ? nil : :failure
      kind = :error if status.signaled?
      output = "Validator failed: #{status}" if kind && output.empty?
      { path: path, kind: kind, message: output }
    end

    def write_case(xml, result)
      path, kind, message = result.values_at(:path, :kind, :message)
      xml.testcase(classname: 'validate', name: path, file: path) do
        if kind
          xml.tag!(kind, message, type: kind == :failure ? 'PuppetValidationFailure' : 'ValidationError')
        elsif !message.empty?
          xml.tag!('system-out', message)
        end
      end
    end
  end
end
