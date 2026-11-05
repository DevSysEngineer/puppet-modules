# frozen_string_literal: true

module ProjectTools
  module Shared
    # File-backed streams avoid pipe deadlocks and preserve the native stream boundary.
    class CommandProcess
      Result = Struct.new(:stdout, :stderr, :status, :error, keyword_init: true)

      attr_reader :pid, :status, :index

      def initialize(index, directory)
        @index = index
        @stdout = File.join(directory, "#{index}.stdout")
        @stderr = File.join(directory, "#{index}.stderr")
      end

      def start(command, combined: false)
        @pid = Process.spawn(*command, pgroup: true, out: [@stdout, 'w', 0o600],
                                       err: combined ? %i[child out] : [@stderr, 'w', 0o600])
      rescue SystemCallError => e
        @error = e
      end

      def finished?
        return true if @error || @status

        finished = Process.waitpid2(@pid, Process::WNOHANG)
        @status = finished.last if finished
        !finished.nil?
      end

      def signal(signal)
        Process.kill(signal, -@pid) if @pid
      rescue Errno::ESRCH
        nil
      end

      def result
        Result.new(stdout: read(@stdout), stderr: read(@stderr), status: @status, error: @error)
      end

      def read(path)
        File.exist?(path) ? File.read(path) : ''
      end
    end
  end
end
