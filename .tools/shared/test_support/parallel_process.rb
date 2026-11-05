# frozen_string_literal: true

require 'fileutils'
require 'json'

module ProjectTools
  # A single batch owns its process group, configuration and separate output streams.
  class ParallelProcess
    TEST_ENV = %w[TEST TESTOPTS TESTOPT TEST_OPTS TEST_OPT].freeze

    attr_reader :pid, :status, :config

    def initialize(work, files, id:, reports:)
      FileUtils.mkdir_p(work, mode: 0o700)
      @config = { 'worker_id' => id, 'selected_files' => files, 'result' => File.join(work, 'result.json'),
                  'reports' => reports ? File.join(work, 'reports') : nil }
      FileUtils.mkdir_p(@config['reports'], mode: 0o700) if reports
      @config_path = File.join(work, 'config.json')
      File.write(@config_path, JSON.generate(@config), mode: 'w', perm: 0o600)
      @streams = %w[stdout stderr].to_h { |channel| [channel, File.join(work, channel)] }
    end

    def start(command, options, root:)
      @pid = Process.spawn(environment, *command, *config['selected_files'], *options,
                           chdir: root, pgroup: true, out: [@streams['stdout'], 'w', 0o600],
                           err: [@streams['stderr'], 'w', 0o600])
    end

    def environment
      TEST_ENV.to_h { |key| [key, nil] }.merge(
        'PROJECT_TOOLS_TEST_WORKER_CONFIG' => @config_path,
        'MINITEST_REPORTERS_REPORTS_DIR' => config['reports']
      )
    end

    def reap?
      return false if status

      finished = Process.waitpid2(pid, Process::WNOHANG)
      @status = finished.last if finished
      !finished.nil?
    end

    def signal(signal)
      # Reaped leaders may still have ordinary descendants in their process group.
      Process.kill(signal, -pid)
    rescue Errno::ESRCH
      nil
    end

    def show_output(console)
      @streams.each do |channel, path|
        text = File.read(path)
        next if text.empty?

        console.diagnostic("#{config['worker_id']} #{channel}:")
        console.diagnostic(text)
      end
    end
  end
end
