# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require 'timeout'

# Interrupt the coordinator externally and verify its workers are reaped before it exits.
class SharedCommandInterruptionTest < Minitest::Test
  def test_signal_reaches_children_and_preserves_completed_diagnostics
    Dir.mktmpdir('command signal ') do |root|
      child = child_script
      script = coordinator(root, child)
      Open3.popen3(RbConfig.ruby, '-e', script) do |input, output, errors, waiter|
        input.close
        interrupt(root, waiter.pid)
        assert_interruption(root, output, errors, waiter)
      end
    end
  end

  def assert_interruption(root, output, errors, waiter)
    assert_equal 'TERM', output.read.strip
    assert_empty errors.read
    assert waiter.value.success?
    assert_equal 'child stopped', File.read(File.join(root, 'diagnostic')).strip
    assert_raises(Errno::ESRCH) { Process.kill(0, Integer(File.read(File.join(root, 'ready')))) }
  end

  def child_script
    <<~'RUBY'
      trap('TERM') { STDERR.puts 'child stopped'; exit 0 }
      path = ARGV.fetch(0)
      File.write("#{path}.tmp", Process.pid)
      File.rename("#{path}.tmp", path)
      sleep
    RUBY
  end

  def coordinator(root, child)
    <<~RUBY
      require 'project_tools/shared/command_pool'
      commands = [[RbConfig.ruby, '-e', #{child.dump}, #{File.join(root, 'ready').dump}]]
      begin
        ProjectTools::Shared::CommandPool.new(commands, jobs: 2).run do |_index, result|
          File.write(#{File.join(root, 'diagnostic').dump}, result.stderr)
        end
      rescue SignalException => error
        puts Signal.signame(error.signo)
      end
    RUBY
  end

  def interrupt(root, pid)
    Timeout.timeout(20) { sleep 0.02 until File.exist?(File.join(root, 'ready')) }
    Process.kill('TERM', pid)
  end
end
