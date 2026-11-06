# frozen_string_literal: true

module ProjectTools
  module Shared
    # File-backed streams avoid pipe deadlocks and preserve the native stream boundary.
    class CommandProcess
      Result = Struct.new(:stdout, :stderr, :status, :error, keyword_init: true)

      attr_reader :pid, :status, :index, :error

      def initialize(index, directory)
        @index = index
        @stdout = File.join(directory, "#{index}.stdout")
        @stderr = File.join(directory, "#{index}.stderr")
      end

      def start(command, combined: false, chdir: nil)
        options = chdir ? { chdir: chdir } : {}
        @pid = Process.spawn(*command, **options, pgroup: true, out: [@stdout, 'w', 0o600],
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
        # Reaped leaders may still have ordinary descendants in their process group.
        Process.kill(signal, -@pid) if @pid
      rescue Errno::ESRCH
        nil
      end

      def result
        streams = {}
        each_stream { |channel, text| streams[channel] = text }
        Result.new(**streams, status: @status, error: @error)
      end

      def each_stream(required: false)
        { stdout: @stdout, stderr: @stderr }.each do |channel, path|
          yield channel, read(path, required: required)
        end
      end

      def read(path, required: false)
        required || File.exist?(path) ? File.read(path) : ''
      end
    end
  end
end
