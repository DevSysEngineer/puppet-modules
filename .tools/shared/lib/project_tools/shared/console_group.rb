# frozen_string_literal: true

module ProjectTools
  module Shared
    # One balanced CI section; callers own its contents and the local text heading.
    class ConsoleGroup
      LOCK = Mutex.new
      @sequence = 0

      def self.next_id
        LOCK.synchronize { @sequence += 1 }
      end

      def initialize(title, output:)
        @title = Console.safe(title)
        @output = output
        @id = "project_#{Process.pid}_#{self.class.next_id}"
      end

      def open
        if ENV['GITHUB_ACTIONS'] == 'true'
          @platform = :github
          @output.puts "::group::#{@title.gsub('%', '%25')}"
        elsif ENV['GITLAB_CI'] == 'true'
          @platform = :gitlab
          @output.puts "\e[0Ksection_start:#{Time.now.to_i}:#{@id}[collapsed=true]\r\e[0K#{@title}"
        end
        @output.flush
        @platform
      end

      def close
        @output.puts '::endgroup::' if @platform == :github
        @output.puts "\e[0Ksection_end:#{Time.now.to_i}:#{@id}\r\e[0K" if @platform == :gitlab
        @output.flush
        @platform = nil
      end

      def during
        yield open
      ensure
        close
      end
    end
  end
end
