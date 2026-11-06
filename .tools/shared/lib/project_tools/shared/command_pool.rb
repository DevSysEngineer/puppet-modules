# frozen_string_literal: true

require 'tmpdir'
require_relative 'worker_count'
require_relative 'command_process'
require_relative 'process_signals'

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
        @signals = ProcessSignals.new
        @results = Array.new(commands.size)
      end

      def run(&completed)
        Dir.mktmpdir('project-tools-commands-') do |directory|
          @signals.during { execute(directory, &completed) }
        end
        raise SignalException, @signals.first if @signals.interrupted?

        @results
      end

      def execute(directory, &completed)
        loop do
          @signals.forward(@workers)
          fill(directory) unless @signals.interrupted?
          collect(&completed)
          break if @active.empty? && (@workers.size == @commands.size || @signals.interrupted?)

          sleep 0.02
        end
      ensure
        drain
      end

      def fill(directory)
        while @active.size < @jobs && @workers.size < @commands.size && !@signals.interrupted?
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

      def signal_all(signal)
        @workers.each { |worker| worker.signal(signal) }
      end

      def drain
        return if @active.empty?

        signal_all('TERM')
        until @active.empty?
          @signals.forward(@workers)
          @active.reject!(&:finished?)
          sleep 0.02 unless @active.empty?
        end
      end
    end
  end
end
