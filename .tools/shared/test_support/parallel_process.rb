# frozen_string_literal: true

require 'fileutils'
require 'forwardable'
require 'json'
require 'project_tools/shared/command_process'

module ProjectTools
  # A single batch owns its process group, configuration and separate output streams.
  class ParallelProcess
    extend Forwardable

    TEST_ENV = %w[TEST TESTOPTS TESTOPT TEST_OPTS TEST_OPT].freeze

    attr_reader :config

    def_delegators :@process, :pid, :status, :signal

    def initialize(work, files, id:, reports:)
      FileUtils.mkdir_p(work, mode: 0o700)
      @config = { 'worker_id' => id, 'selected_files' => files, 'result' => File.join(work, 'result.json'),
                  'reports' => reports ? File.join(work, 'reports') : nil }
      FileUtils.mkdir_p(@config['reports'], mode: 0o700) if reports
      @config_path = File.join(work, 'config.json')
      File.write(@config_path, JSON.generate(@config), mode: 'w', perm: 0o600)
      @process = Shared::CommandProcess.new(id, work)
    end

    def start(command, options, root:)
      @process.start([environment, *command, *config['selected_files'], *options], chdir: root)
      # Test batches stop after a start failure; the native command pool records it and continues.
      raise @process.error if @process.error
    end

    def environment
      TEST_ENV.to_h { |key| [key, nil] }.merge(
        'PROJECT_TOOLS_TEST_WORKER_CONFIG' => @config_path,
        'MINITEST_REPORTERS_REPORTS_DIR' => config['reports']
      )
    end

    def reap?
      return false if status

      @process.finished?
    end

    def show_output(console)
      @process.each_stream(required: true) do |channel, text|
        next if text.empty?

        console.diagnostic("#{config['worker_id']} #{channel}:")
        console.diagnostic(text)
      end
    end
  end
end
