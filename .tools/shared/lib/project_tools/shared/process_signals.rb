# frozen_string_literal: true

module ProjectTools
  module Shared
    # Both process coordinators forward the first interruption and escalate later signals.
    class ProcessSignals
      def initialize
        @received = []
        @forwarded = 0
      end

      def first
        @received.first
      end

      def interrupted?
        !@received.empty?
      end

      def during
        previous = %w[INT TERM].to_h { |signal| [signal, Signal.trap(signal) { @received << signal }] }
        yield
      ensure
        previous&.each { |signal, handler| Signal.trap(signal, handler) }
      end

      def forward(workers)
        return unless @received.size > @forwarded

        signal = @forwarded.zero? && @received.size == 1 ? first : 'KILL'
        workers.each { |worker| worker.signal(signal) }
        @forwarded = @received.size
      end
    end
  end
end
