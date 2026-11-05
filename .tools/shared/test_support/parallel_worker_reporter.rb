# frozen_string_literal: true

module ProjectTools
  # Native Minitest still owns execution; this sink only transfers its results.
  class TestWorkerReporter < TestConsoleReporter
    def initialize(config)
      super()
      @config = config
    end

    def on_start
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @expected = options[:total_count] unless options[:exclude]
      @running = {}
      TestConsoleReporter.terminal_outputs = [io, $stdout, $stderr]
      at_exit { interrupted unless @reported }
      prepare_report
    end

    def prepare_report
      return unless @config['reports']

      @junit = Minitest::Reporters::JUnitReporter.new(@config.fetch('reports'), false)
      @junit.io = StringIO.new
      @junit.start
    rescue SystemCallError, IOError => e
      @report_error = "Cannot prepare test JUnit reports: #{e.message}"
    end

    def on_record(test)
      track_result(test)
      native_on_record(test) if options[:verbose]
    end

    def on_report
      begin
        @junit&.report
      rescue SystemCallError, IOError => e
        @report_error = "Cannot write test JUnit reports: #{e.message}"
      end
      publish(completeness.split.first)
    ensure
      TestConsoleReporter.terminal_outputs = nil
    end

    def passed?
      super && !@report_error && !incomplete?
    end

    def interrupted
      publish('incomplete')
    ensure
      TestConsoleReporter.terminal_outputs = nil
    end

    def case_records
      tests.map do |test|
        outcome = { pass: 'passed', fail: 'failure', error: 'error', skip: 'skipped' }.fetch(result(test))
        { class_name: test_class(test).to_s, test_name: test.name, outcome: outcome }
      end
    end

    def native_counts
      outcomes = case_records.map { |test| test[:outcome] }.tally
      { tests: count, assertions: assertions, failures: outcomes.fetch('failure', 0),
        errors: outcomes.fetch('error', 0), skips: outcomes.fetch('skipped', 0) }
    end

    def native_findings
      tests.reject(&:passed?).map do |test|
        { class_name: test_class(test).to_s, test_name: test.name, message: message_for(test) }
      end
    end

    def result_data(execution)
      { schema_version: 1, worker_id: @config.fetch('worker_id'),
        selected_files: @config.fetch('selected_files'), execution: execution,
        expected_tests: @expected, counts: native_counts, cases: case_records, findings: native_findings,
        seed: options[:seed], duration_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started,
        junit_files: report_names, report_error: @report_error }
    end

    def report_names
      @config['reports'] ? Dir.children(@config['reports']).grep(/\ATEST-.*\.xml\z/).sort : []
    rescue SystemCallError, IOError => e
      @report_error ||= "Cannot list test JUnit reports: #{e.message}"
      []
    end

    def publish(execution)
      path = @config.fetch('result')
      File.write("#{path}.tmp", JSON.generate(result_data(execution)), mode: 'w', perm: 0o600)
      File.rename("#{path}.tmp", path)
      @reported = true
    end
  end
end
