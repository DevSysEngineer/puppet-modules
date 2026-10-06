# frozen_string_literal: true

module ProjectTools
  module Shared
    # Presentation only: callers supply the outcome, coverage and diagnostics.
    class Console
      INTERVAL = 15

      def initialize(name, output: $stdout, scope: nil, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        @name = name
        @output = output
        @clock = clock
        @started = @clock.call
        @processed = 0
        @previous = 0
        @findings = []
        @mutex = Mutex.new
        line(["[START] #{@name}", scope].compact.join(' | '))
      end

      def during
        start_activity
        yield
      ensure
        stop_activity
        unless @finished
          facts = @unit ? ["Processed: #{@processed} #{@unit}"] : []
          finish(status: 'ERROR', execution: 'incomplete', facts: facts,
                 details: @findings + ['Execution ended before a result was available.'])
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

      def finding(message, output: @output)
        @mutex.synchronize do
          @findings << message
          brief = message.to_s.lines.first(2).map { |part| safe(part.chomp) }.join(' | ')
          line("[FINDING] #{@name} | #{brief}", output: output)
        end
      end

      def finish(status:, execution:, facts: [], details: [], report: nil)
        stop_activity
        @finished = true
        line("\n[#{status}] #{@name}")
        line("Execution: #{execution}")
        facts.each { |fact| line(safe(fact)) }
        details.each { |detail| diagnostic(detail) }
        yield if block_given?
        line(format('Duration: %.1f s', @clock.call - @started))
        line("JUnit written: #{safe(report)}") if report
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
