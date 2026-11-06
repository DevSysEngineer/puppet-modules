# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require 'project_tools/shared/command_pool'

# Real subprocesses exercise stream pressure, completion order and spawn failures.
class SharedCommandExecutionTest < Minitest::Test
  def command(script)
    [RbConfig.ruby, '-e', script]
  end

  def test_large_separate_streams_and_native_exit_status_are_preserved
    commands = [command("STDOUT.write('o' * 200_000); STDERR.write('e' * 200_000); exit 7"), command("puts 'later'")]
    results = ProjectTools::Shared::CommandPool.new(commands, jobs: 2).run
    assert_streams(results.first)
    assert_equal "later\n", results.last.stdout
    assert results.last.status.success?
  end

  def assert_streams(result)
    assert_equal 'o' * 200_000, result.stdout
    assert_equal 'e' * 200_000, result.stderr
    assert_equal 7, result.status.exitstatus
  end

  def test_combined_output_and_start_failure_do_not_discard_later_commands
    commands = [['/missing-synthetic-command'], command("STDOUT.sync = true; print 'out'; STDERR.print 'err'")]
    results = ProjectTools::Shared::CommandPool.new(commands, jobs: 8, combined: true).run
    assert_kind_of Errno::ENOENT, results.first.error
    assert_equal 'outerr', results.last.stdout
    assert_empty results.last.stderr
    assert results.last.status.success?
  end

  def test_results_use_selection_order_while_callback_follows_completion
    Dir.mktmpdir('command completion ') do |root|
      release = File.join(root, 'release')
      completed = []
      results = ProjectTools::Shared::CommandPool.new(ordered_commands(release), jobs: 2).run do |index, _result|
        completed << index
        File.write(release, '') if index == 1
      end
      assert_equal [1, 0], completed
      assert_equal %W[first\n second\n], results.map(&:stdout)
    end
  end

  def ordered_commands(release)
    [command("sleep 0.01 until File.exist?(#{release.dump}); puts 'first'"), command("puts 'second'")]
  end

  def test_invalid_limits_cannot_start_a_command
    [0, -1, '', '2x', ' 2', '1.5', nil].each do |jobs|
      assert_raises(ArgumentError) { ProjectTools::Shared::CommandPool.new([command("abort 'started'")], jobs: jobs) }
    end
    assert_empty ProjectTools::Shared::CommandPool.new([], jobs: 4).run
  end

  def test_previous_signal_handlers_survive_callback_failure
    original = %w[INT TERM].to_h { |signal| [signal, Signal.trap(signal, 'IGNORE')] }
    pool = ProjectTools::Shared::CommandPool.new([command("puts 'done'")], jobs: 1)
    assert_raises(IOError) { pool.run { raise IOError, 'synthetic callback failure' } }
    %w[INT TERM].each { |signal| assert_equal 'IGNORE', Signal.trap(signal, 'IGNORE') }
  ensure
    original&.each { |signal, handler| Signal.trap(signal, handler) }
  end
end
