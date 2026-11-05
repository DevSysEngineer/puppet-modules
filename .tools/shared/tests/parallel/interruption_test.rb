# frozen_string_literal: true

require_relative 'support'

# Verify cancellation against synchronized children, without timing-based overlap assertions.
class ParallelInterruptionTest < Minitest::Test
  include ParallelTestSupport

  def test_sigint_and_sigterm_reach_workers_and_their_children
    %w[INT TERM].each { |signal| assert_interruption(signal) }
  end

  def test_second_signal_kills_workers_that_handle_the_first_signal
    %w[Alpha Beta].each { |name| stubborn_probe(name) }
    pid = start_controller
    interrupt_twice(pid)
    refute Timeout.timeout(20) { Process.waitpid2(pid).last }.success?
    assert_interrupted_output
    assert_workers_stopped
  ensure
    clean_processes(pid)
  end

  def interrupt_twice(pid)
    %w[Alpha Beta].each { |name| wait_for_file("#{name}-worker") }
    Process.kill('INT', pid)
    %w[Alpha Beta].each { |name| wait_for_file("#{name}-interrupted") }
    Process.kill('TERM', pid)
  end

  def stubborn_probe(name)
    probe(name, <<~RUBY)
      Signal.trap('INT') { File.write('#{name}-interrupted', 'yes') }
      File.write('#{name}-worker', Process.pid.to_s)
      sleep
    RUBY
  end

  def assert_workers_stopped
    %w[Alpha Beta].each do |name|
      assert_raises(Errno::ESRCH) { Process.kill(0, Integer(read("#{name}-worker"))) }
    end
  end

  def interruption_probe(name, signal)
    probe(name, <<~RUBY)
      File.write('#{name}-worker', Process.pid.to_s)
      child = Process.spawn(RbConfig.ruby, '-e',
        "Signal.trap('#{signal}') { File.write('#{name}-stopped', 'yes'); exit }; File.write('#{name}-ready', Process.pid.to_s); sleep")
      begin
        sleep
      ensure
        Process.wait(child)
      end
    RUBY
  end

  def start_controller
    Process.spawn(environment, RbConfig.ruby, Gem.bin_path('rake', 'rake'), 'test:tools', '--jobs=2',
                  chdir: @project, pgroup: true, out: File.join(@project, 'signal-output'), err: %i[child out])
  end

  def assert_interruption(signal)
    %w[Alpha Beta].each { |name| interruption_probe(name, signal) }
    pid = start_controller
    %w[Alpha Beta].each { |name| wait_for_file("#{name}-ready") }
    Process.kill(signal, pid)
    status = Timeout.timeout(20) { Process.waitpid2(pid).last }
    refute status.success?
    assert_interrupted_output
    assert_children_stopped
  ensure
    clean_processes(pid)
  end

  def assert_interrupted_output
    assert_includes read('signal-output'), 'Execution: incomplete'
    refute_includes read('signal-output'), '[PASSED]'
  end

  def assert_children_stopped
    %w[Alpha Beta].each do |name|
      assert_equal 'yes', read("#{name}-stopped")
      child = Integer(read("#{name}-ready"))
      assert_raises(Errno::ESRCH) { Process.kill(0, child) }
      File.delete(File.join(@project, "#{name}-ready"))
    end
  end

  def clean_processes(pid)
    pids = %w[Alpha Beta].filter_map do |name|
      path = File.join(@project, "#{name}-worker")
      Integer(File.read(path)) if File.exist?(path)
    end
    [pid, *pids].compact.each do |child|
      Process.kill('KILL', -child)
    rescue Errno::ESRCH
      next
    end
  end
end
