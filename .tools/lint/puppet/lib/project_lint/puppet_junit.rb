# frozen_string_literal: true

require 'json'
require_relative 'puppet_junit_command'
require 'project_lint/junit_report'
require 'project_tools/shared/console'

module ProjectLint
  # Converts native Puppet-lint JSON; detection, selection and exit status remain with the native CLI.
  class PuppetJunit
    extend PuppetJunitCommand

    # Distinguish findings from converter/startup failures without changing the native lint policy.
    FINDINGS_STATUS = 10

    def initialize(input)
      groups = JSON.parse(input)
      raise ArgumentError, 'Expected native Puppet-lint JSON arrays' unless groups.is_a?(Array) && groups.all?(Array)
      raise ArgumentError, 'No files were reported by Puppet-lint' if groups.empty?

      @files = groups.size
      @problems = groups.flatten(1)
      @problems.each { |problem| validate(problem) }
    end

    def validate(problem)
      unless problem.is_a?(Hash) && valid_fields?(problem) && %w[warning error ignored fixed].include?(problem['kind'])
        raise ArgumentError, 'Invalid Puppet-lint diagnostic'
      end
    end

    def valid_fields?(problem)
      strings = %w[path check kind message]
      positions = %w[line column]
      strings.all? { |key| problem[key].is_a?(String) } &&
        positions.all? { |key| problem[key].is_a?(Integer) && problem[key] >= 0 }
    end

    def write(output, console)
      present(console)
      write_findings(output)
    end

    def present(console, errors: [], errors_output: console)
      findings = ProjectTools::Shared::ConsoleFindings.new(output: console)
      @problems.each { |problem| present_problem(findings, problem) unless problem['kind'] == 'ignored' }
      errors.each { |message| findings.add(message, kind: :error, title: 'Puppet lint report', output: errors_output) }
      console.puts 'Puppet lint: no active findings.' if active.empty?
      console.puts "Files reported by Puppet-lint: #{@files}"
      console.puts "Findings: #{counts.join(' | ')}"
      findings.write
      console.flush
    end

    def present_problem(findings, problem)
      kind = { 'error' => :failure, 'warning' => :warning, 'fixed' => :info }.fetch(problem['kind'])
      findings.add(diagnostic(problem), kind: kind, title: problem['check'],
                                        source: problem.values_at('path', 'line', 'column').join(':'),
                                        subject: problem['path'], unit: 'file')
    end

    def counts
      %w[error warning fixed ignored].map { |kind| "#{@problems.count { |p| p['kind'] == kind }} #{kind}" }
    end

    def write_findings(output)
      groups = active.group_by { |problem| [problem.fetch('path'), problem.fetch('check')] }
      JunitReport.write(output, name: 'puppet-lint', tests: [groups.length, 1].max, failures: groups.length,
                                errors: 0) do |xml|
        xml.testcase(classname: 'puppet-lint', name: 'Puppet lint scan') if groups.empty?
        groups.each { |(path, check), problems| write_case(xml, path, check, problems) }
      end
    end

    def write_case(xml, path, check, problems)
      xml.testcase(classname: 'puppet-lint', name: "#{path}:#{check}", file: path) do
        xml.failure(problems.map { |problem| diagnostic(problem) }.join("\n"), type: check)
      end
    end

    def diagnostic(problem)
      format('%<path>s:%<line>d:%<column>d: %<check>s: %<kind>s: %<message>s', problem.transform_keys(&:to_sym))
    end

    def active
      @problems.select { |problem| %w[warning error].include?(problem['kind']) }
    end

    def self.convert(input, output, console, errors)
      converter, message = read(input)
      if converter
        converter.write(output, console)
        return 0
      end

      report_error(message, errors)
      write_error(output, message)
      1
    end

    def self.read(input)
      [new(input.read), nil]
    rescue JSON::ParserError, ArgumentError => e
      # Do not include parser excerpts: the input can contain source context.
      message = e.is_a?(JSON::ParserError) ? 'Invalid or missing Puppet-lint JSON; inspect the lint log.' : e.message
      [nil, message]
    end

    def self.report_error(message, output)
      findings = ProjectTools::Shared::ConsoleFindings.new(output: output)
      Array(message).each { |text| findings.add(text, kind: :error, title: 'Puppet lint report') }
      findings.write
    end

    def self.write_error(output, message)
      JunitReport.write(output, name: 'puppet-lint', tests: 1, failures: 0, errors: 1) do |xml|
        xml.testcase(classname: 'puppet-lint', name: 'Puppet lint report') { xml.error(message, type: 'ReportError') }
      end
    end
  end
end
