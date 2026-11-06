# frozen_string_literal: true

require 'project_tools/shared/console'
require 'stringio'

module ProjectTools
  # Development-only adapter; native Minitest owns test outcomes and JUnit cases.
  class TestConsoleReporter < Minitest::Reporters::DefaultReporter
    alias native_on_record on_record
    # Keep headers out of the suite log while exercising their normal rendering in tests.
    module SoftwareOutput
      def software(tool, output: $stderr, **options)
        streams = TestConsoleReporter.terminal_outputs
        output = StringIO.new if streams&.any? { |stream| stream.equal?(output) }
        super
      end
    end

    class << self
      attr_accessor :terminal_outputs, :software
    end

    def on_start
      @expected = options[:total_count] unless options[:exclude]
      @running = {}
      start_console
      @console.start_activity
      at_exit { interrupted unless @reported }
      self.class.terminal_outputs = [io, $stdout, $stderr]
      prepare_report
    end

    def start_console
      scope = @expected ? "#{@expected} tests selected" : 'filtered tests; total unknown'
      @console = Shared::Console.new('Tool tests', output: io, scope: scope, software: software)
      @console.diagnostic("Packages: #{packages.join(', ')}")
      @console.diagnostic("Run options: #{options[:args]}")
    end

    def packages
      tools = Gem.loaded_specs.values.select { |spec| spec.name.match?(/\A(?:project-tools-|lint-project\z)/) }
      tools.sort_by(&:name).map { |spec| "#{spec.name} #{spec.version}" }
    end

    def software
      TestConsoleReporter.software || { tool: 'project-tools-shared', runtime: false }
    end

    def before_test(test)
      @running[[test.class.to_s, test.name]] = true
      super
    end

    def prepare_report
      return unless ENV['MINITEST_REPORTERS_REPORTS_DIR']

      @junit = Minitest::Reporters::JUnitReporter.new(ENV.fetch('MINITEST_REPORTERS_REPORTS_DIR'))
      @junit.io = io
      @junit.start
    end

    def on_record(test)
      track_result(test)
      @console.advance(unit: 'tests', total: @expected)
      record_finding(test) unless test.passed?
      super if options[:verbose]
    end

    def record_finding(test)
      kind = { fail: :failure, error: :error, skip: :skipped }.fetch(result(test))
      identity = "#{test_class(test)}##{test.name}"
      @console.finding(message_for(test), kind: kind, title: identity, subject: identity, unit: 'test')
    end

    def track_result(test)
      @running.delete([test_class(test).to_s, test.name])
      @junit&.record(test)
    end

    def on_report
      @junit&.report
      status = failures.positive? ? 'FAILED' : 'PASSED'
      status = 'ERROR' if errors.positive? || incomplete?
      finish(status, completeness)
    rescue SystemCallError, IOError => e
      finish('ERROR', 'incomplete', error: "Cannot write test JUnit reports: #{e.message}")
      raise
    ensure
      self.class.terminal_outputs = nil
    end

    def completeness
      return 'incomplete' if incomplete?
      return 'unknown (filtered total unavailable)' unless @expected

      'complete'
    end

    def incomplete?
      @running.any? || (@expected && count != @expected)
    end

    def finish(status, execution, error: nil)
      @console.finish(status: status, execution: execution, facts: [result_line], details: Array(error),
                      report: @junit && !error && tests.any? ? "#{@junit.reports_path}/TEST-*.xml" : nil)
      @reported = true
    end

    def interrupted
      @console.stop_activity
      @console.finish(status: 'ERROR', execution: 'incomplete',
                      details: ['Test execution or required reporting did not complete.'])
    ensure
      self.class.terminal_outputs = nil
    end
  end
end
