# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require 'timeout'

# A second signal kills an uncooperative worker without starting queued work.
class SharedCommandEscalationTest < Minitest::Test
  def test_second_signal_reaps_the_worker_and_preserves_the_original_signal
    Dir.mktmpdir('command escalation ') do |root|
      Open3.popen3(RbConfig.ruby, '-e', coordinator, root) do |input, output, errors, waiter|
        input.close
        signal_sequence(root, waiter.pid)
        assert_equal 'TERM', output.read.strip
        assert_empty errors.read
        assert waiter.value.success?
        assert_cleanup(root)
      end
    end
  end

  def assert_cleanup(root)
    refute_path_exists File.join(root, 'queued')
    pid = Integer(File.read(File.join(root, 'ready')))
    assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
    assert_equal Signal.list.fetch('KILL'), Integer(File.read(File.join(root, 'status')))
  end

  def signal_sequence(root, pid)
    wait_for(File.join(root, 'ready'))
    Process.kill('TERM', pid)
    wait_for(File.join(root, 'ack'))
    Process.kill('INT', pid)
  end

  def wait_for(path)
    Timeout.timeout(20) { sleep 0.02 until File.exist?(path) }
  end

  def coordinator
    <<~RUBY
      require 'project_tools/shared/command_pool'
      root = ARGV.fetch(0)
      child = <<~'CHILD'
        root = ARGV.fetch(0)
        trap('TERM') { File.write(File.join(root, 'ack'), '') }
        File.write(File.join(root, 'pending'), Process.pid)
        File.rename(File.join(root, 'pending'), File.join(root, 'ready'))
        sleep
      CHILD
      commands = [[RbConfig.ruby, '-e', child, root],
                  [RbConfig.ruby, '-e', 'File.write(ARGV.fetch(0), "queued")', File.join(root, 'queued')]]
      begin
        ProjectTools::Shared::CommandPool.new(commands, jobs: 1).run do |_index, result|
          File.write(File.join(root, 'status'), result.status.termsig)
        end
      rescue SignalException => error
        puts Signal.signame(error.signo)
      end
    RUBY
  end
end
