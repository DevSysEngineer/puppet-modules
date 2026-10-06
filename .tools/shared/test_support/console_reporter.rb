# frozen_string_literal: true

require 'project_tools/shared/console'

module ProjectTools
  # Development-only adapter; native Minitest owns test outcomes and JUnit cases.
  class TestConsoleReporter < Minitest::Reporters::DefaultReporter
    def on_start
      @expected = options[:total_count] unless options[:exclude]
      @running = {}
      scope = @expected ? "#{@expected} tests selected" : 'filtered tests; total unknown'
      @console = Shared::Console.new('Tool tests', output: io, scope: scope)
      @console.diagnostic("Run options: #{options[:args]}")
      @console.start_activity
      at_exit { interrupted unless @reported }
      prepare_report
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
      @running.delete([test_class(test).to_s, test.name])
      @junit&.record(test)
      @console.advance(unit: 'tests', total: @expected)
      @console.finding(message_for(test)) unless test.passed?
      super if options[:verbose]
    end

    def on_report
      @junit&.report
      status = failures.positive? ? 'FAILED' : 'PASSED'
      status = 'ERROR' if errors.positive? || incomplete?
      finish(status, completeness)
    rescue SystemCallError, IOError => e
      finish('ERROR', 'incomplete', error: "Cannot write test JUnit reports: #{e.message}")
      raise
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
      @console.finish(status: status, execution: execution, facts: [result_line], details: diagnostics + Array(error),
                      report: @junit && !error && tests.any? ? "#{@junit.reports_path}/TEST-*.xml" : nil)
      @reported = true
    end

    def diagnostics
      tests.reject(&:passed?).sort_by { |test| [test_class(test).to_s, test.name] }.map { |test| message_for(test) }
    end

    def interrupted
      @console.stop_activity
      @console.finish(status: 'ERROR', execution: 'incomplete',
                      details: diagnostics +
                        ['Test execution or required reporting did not complete; see native diagnostic above.'])
    end
  end
end
