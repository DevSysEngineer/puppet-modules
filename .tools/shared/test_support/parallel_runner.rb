# frozen_string_literal: true

require 'tmpdir'
require 'project_tools/shared/console'
require_relative 'parallel_task'
require_relative 'parallel_process'
require_relative 'parallel_results'

module ProjectTools
  # Coordinate isolated native test processes without loading Minitest in this process.
  class ParallelRunner
    attr_writer :software

    def initialize(plan, command:, options: [], name: 'Tool tests', root: Dir.pwd)
      @plan = plan
      @command = command
      @options = options
      @name = name
      @root = root
      destination = ENV.fetch('MINITEST_REPORTERS_REPORTS_DIR', nil)
      @destination = File.expand_path(destination, root) if destination
      @results = ParallelResults.new
      @workers = []
      @signals = []
    end

    def run
      start_console
      @console.during do
        Dir.mktmpdir('parallel-tooltests-') do |directory|
          with_signals { execute(directory) }
          @results.finish(@console, @workers, @destination)
        end
      end
      raise SignalException, @signals.first unless @signals.empty?

      @results.status == 'PASSED' ? 0 : 1
    end

    def start_console
      scope = "#{@name} | #{@plan.files.size} files | #{@plan.groups.size} groups | #{@plan.effective_jobs} workers"
      scope += " (#{@plan.requested_jobs} requested)" if @plan.effective_jobs != @plan.requested_jobs
      @console = Shared::Console.new('Tool tests', scope: scope, software: software)
    end

    def software
      value = @software.respond_to?(:call) ? @software.call : @software
      value || { tool: 'project-tools-shared', runtime: false }
    end

    def execute(directory)
      prepare_destination
      start_workers(directory)
      wait_for_workers
    rescue StandardError => e
      @results.errors << "Cannot execute workers: #{e.class}: #{e.message}"
      signal_workers('TERM')
      wait_for_workers
    ensure
      collect_results
    end

    def start_workers(directory)
      @plan.batches.each_with_index do |files, index|
        break unless @signals.empty?

        start_worker(directory, files, index)
      end
    end

    def prepare_destination
      return unless @destination

      FileUtils.mkdir_p(@destination)
      Dir.glob('TEST-*.xml', base: @destination).each { |name| File.delete(File.join(@destination, name)) }
    end

    def start_worker(directory, files, index)
      id = format('worker-%02d', index)
      worker = ParallelProcess.new(File.join(directory, id), files, id: id, reports: @destination)
      worker.start(@command, @options, root: @root)
      @workers << worker
    end

    def with_signals
      previous = %w[INT TERM].to_h { |signal| [signal, Signal.trap(signal) { @signals << signal }] }
      yield
    ensure
      previous&.each { |signal, handler| Signal.trap(signal, handler) }
    end

    def wait_for_workers
      @forwarded = 0
      loop do
        forward_signals
        @workers.each do |worker|
          @console.advance(unit: 'worker batches', total: @plan.effective_jobs) if worker.reap?
        end
        break if @workers.all?(&:status)

        sleep 0.05
      end
    end

    def forward_signals
      return unless @signals.size > @forwarded

      signal_workers(@forwarded.zero? && @signals.size == 1 ? @signals.first : 'KILL')
      @forwarded = @signals.size
    end

    def signal_workers(signal)
      @workers.each { |worker| worker.signal(signal) }
    end

    def collect_results
      @workers.each do |worker|
        paths = @results.accept(worker.config, worker.status)
        @results.publish(paths, @destination) if @destination
      end
      @results.errors << 'Not all selected worker batches started.' if @workers.size != @plan.effective_jobs
      @results.errors << "Interrupted by #{@signals.first}." unless @signals.empty?
    end
  end
end
