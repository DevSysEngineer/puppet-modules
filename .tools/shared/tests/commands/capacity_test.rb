# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require 'project_tools/shared/command_pool'
require 'timeout'

# A barrier proves the worker bound without comparing wall-clock timings.
class SharedCommandCapacityTest < Minitest::Test
  def test_only_the_requested_number_of_native_processes_runs_concurrently
    [1, 2, 4, 8].each do |jobs|
      Dir.mktmpdir('command capacity ') { |root| assert_capacity(root, jobs) }
    end
  end

  def assert_capacity(root, jobs)
    limit = [jobs, 4].min
    commands = 4.times.map { |index| [RbConfig.ruby, '-e', barrier, root, index.to_s, limit.to_s] }
    results = Timeout.timeout(20) { ProjectTools::Shared::CommandPool.new(commands, jobs: jobs).run }
    assert(results.all? { |result| result.status.success? })
    assert_counts(event_counts(root), limit)
  end

  def event_counts(root)
    active = 0
    File.readlines(File.join(root, 'events')).map { |event| active += event.start_with?('start') ? 1 : -1 }
  end

  def assert_counts(counts, limit)
    assert_equal limit, counts.max
    assert_equal 0, counts.last
    assert(counts.all? { |count| count.between?(0, limit) })
  end

  def barrier
    <<~'RUBY'
      root, index, limit = ARGV
      index, limit = index.to_i, limit.to_i
      event = ->(name) do
        File.open(File.join(root, 'events'), 'a') { |file| file.flock(File::LOCK_EX); file.puts(name) }
      end
      event.call('start')
      File.write(File.join(root, "#{index}.ready"), '')
      group = (index / limit * limit)...((index / limit + 1) * limit)
      sleep 0.01 until group.all? { |member| File.exist?(File.join(root, "#{member}.ready")) }
      event.call('end')
    RUBY
  end
end
