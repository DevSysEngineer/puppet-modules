# frozen_string_literal: true

require 'tmpdir'
require_relative 'worker_count'
require_relative 'command_process'

module ProjectTools
  module Shared
    # Bound fresh native processes; callers retain selection, classification and presentation.
    class CommandPool
      def initialize(commands, jobs:, combined: false)
        @commands = commands
        @jobs = WorkerCount.parse(jobs)
        @combined = combined
        @workers = []
        @active = []
        @signals = []
        @forwarded = 0
        @results = Array.new(commands.size)
      end

      def run(&completed)
        Dir.mktmpdir('project-tools-commands-') do |directory|
          with_signals { execute(directory, &completed) }
        end
        raise SignalException, @signals.first unless @signals.empty?

        @results
      end

      def with_signals
        previous = %w[INT TERM].to_h { |signal| [signal, Signal.trap(signal) { @signals << signal }] }
        yield
      ensure
        previous&.each { |signal, handler| Signal.trap(signal, handler) }
      end

      def execute(directory, &completed)
        loop do
          forward_signals
          fill(directory) if @signals.empty?
          collect(&completed)
          break if @active.empty? && (@workers.size == @commands.size || @signals.any?)

          sleep 0.02
        end
      ensure
        drain
      end

      def fill(directory)
        while @active.size < @jobs && @workers.size < @commands.size && @signals.empty?
          worker = CommandProcess.new(@workers.size, directory)
          @workers << worker
          @active << worker
          worker.start(@commands.fetch(worker.index), combined: @combined)
        end
      end

      def collect
        @active.dup.each do |worker|
          next unless worker.finished?

          @active.delete(worker)
          @results[worker.index] = worker.result
          yield worker.index, @results[worker.index] if block_given?
        end
      end

      def forward_signals
        return unless @signals.size > @forwarded

        signal_all(@forwarded.zero? && @signals.size == 1 ? @signals.first : 'KILL')
        @forwarded = @signals.size
      end

      def signal_all(signal)
        @workers.each { |worker| worker.signal(signal) }
      end

      def drain
        return if @active.empty?

        signal_all('TERM')
        until @active.empty?
          forward_signals
          @active.reject!(&:finished?)
          sleep 0.02 unless @active.empty?
        end
      end
    end
  end
end
