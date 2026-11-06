# frozen_string_literal: true

require_relative 'software'
require_relative 'console_findings'
require_relative 'console_group'

module ProjectTools
  module Shared
    # Presentation only: callers supply the outcome, coverage and diagnostics.
    class Console
      extend Software

      INTERVAL = 15

      def initialize(name, output: $stdout, scope: nil, software: nil,
                     clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        @name = safe(name)
        @output = output
        @clock = clock
        @started = @clock.call
        @processed = @previous = 0
        @findings = ConsoleFindings.new(output: output)
        @mutex = Mutex.new
        @group = ConsoleGroup.new("Run #{@name}", output: output)
        start(scope, software)
      end

      def start(scope, software)
        @group.open
        line(["[START] #{@name}", scope].compact.join(' | '))
        self.class.software(software.fetch(:tool), **software.except(:tool), output: @output) if software
      end

      def during
        start_activity
        yield
      ensure
        stop_activity
        unless @finished
          facts = @unit ? ["Processed: #{@processed} #{@unit}"] : []
          finish(status: 'ERROR', execution: 'incomplete', facts: facts,
                 details: ['Execution ended before a result was available.'])
        end
      end

      def start_activity
        @activity = Thread.new do
          loop do
            sleep INTERVAL
            progress
          end
        end
      end

      def stop_activity
        @activity&.kill
        @activity&.join
        @activity = nil
      end

      def advance(unit:, total: nil)
        @mutex.synchronize do
          @processed += 1
          @unit = unit
          @total = total
        end
      end

      def progress
        @mutex.synchronize do
          elapsed = (@clock.call - @started).to_i
          if @processed > @previous
            count = @total ? "#{@processed}/#{@total}" : @processed.to_s
            line("[PROGRESS] #{@name} | #{count} #{@unit} processed | #{elapsed} s")
          else
            line("[PROGRESS] #{@name} | Still running | #{elapsed} s | no new results")
          end
          @previous = @processed
        end
      end

      def finding(message, subject: nil, output: @output, **metadata)
        @mutex.synchronize do
          @findings.add(message, subject: subject, output: output, **metadata)
        end
      end

      def finish(status:, execution:, facts: [], details: [], report: nil)
        return if @finished

        stop_activity
        @finished = true
        @group.close
        result_header(status, execution, facts)
        @findings.write(details: details, kind: { 'ERROR' => :error, 'FAILED' => :failure }.fetch(status, :info))
        yield if block_given?
        line(format('Duration: %.1f s', @clock.call - @started))
        line("JUnit written: #{safe(report)}") if report
      end

      def result_header(status, execution, facts)
        line("\n[#{status}] #{@name}")
        line("Execution: #{execution}")
        facts.each { |fact| line(safe(fact)) }
      end

      def diagnostic(message, output: @output)
        self.class.diagnostic(message, output: output)
      end

      def safe(value)
        self.class.safe(value)
      end

      def self.diagnostic(message, output:)
        message.to_s.each_line { |part| output.puts "  #{safe(part.chomp)}" }
        output.flush
      end

      def self.safe(value)
        value.to_s.encode('UTF-8', invalid: :replace, undef: :replace).gsub(/[[:cntrl:]]/, ' ')
      end

      def line(message, output: @output)
        output.puts message
        output.flush
      end
    end
  end
end
