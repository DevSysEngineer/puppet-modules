# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require_relative '../../test_support/parallel_process'
require 'timeout'

# The test adapter keeps its environment, working directory and one-time completion contract.
class ParallelProcessTest < Minitest::Test
  def test_native_streams_arguments_and_working_directory_are_preserved
    Dir.mktmpdir('parallel process ') do |root|
      argument = 'synthetic $(command); path.rb'
      worker = ProjectTools::ParallelProcess.new(root, [argument], id: 'worker-00', reports: false)
      worker.start([RbConfig.ruby, '-e', script], ['--synthetic-option'], root: root)
      Timeout.timeout(20) { sleep 0.01 until worker.reap? }
      refute worker.reap?
      assert_equal 7, worker.status.exitstatus
      assert_output(worker, root, argument)
      assert_private_streams(root)
    end
  end

  def script
    <<~RUBY
      require 'json'
      puts JSON.generate(directory: Dir.pwd, arguments: ARGV, test_options: ENV['TESTOPTS'],
                         configuration: ENV['PROJECT_TOOLS_TEST_WORKER_CONFIG'],
                         reports: ENV['MINITEST_REPORTERS_REPORTS_DIR'])
      STDERR.puts 'synthetic stderr'
      exit 7
    RUBY
  end

  def captured_output(worker)
    messages = []
    console = Object.new
    console.define_singleton_method(:diagnostic) { |text| messages << text }
    worker.show_output(console)
    messages
  end

  def assert_output(worker, root, argument)
    messages = captured_output(worker)
    assert_equal ['worker-00 stdout:', 'worker-00 stderr:', "synthetic stderr\n"],
                 messages.values_at(0, 2, 3)
    assert_equal({ 'directory' => File.realpath(root), 'arguments' => [argument, '--synthetic-option'],
                   'test_options' => nil, 'reports' => nil, 'configuration' => File.join(root, 'config.json') },
                 JSON.parse(messages.fetch(1)))
  end

  def assert_private_streams(root)
    paths = Dir[File.join(root, '*.stdout'), File.join(root, '*.stderr')]
    assert_equal %w[worker-00.stderr worker-00.stdout], paths.map { |path| File.basename(path) }.sort
    paths.each do |path|
      assert_equal 0o600, File.stat(path).mode & 0o777
    end
  end

  def test_missing_worker_streams_remain_errors
    %w[stdout stderr].each do |channel|
      Dir.mktmpdir('parallel missing stream ') do |root|
        worker = ProjectTools::ParallelProcess.new(root, [], id: 'worker-00', reports: false)
        worker.start([RbConfig.ruby, '-e', "puts 'available output'"], [], root: root)
        Timeout.timeout(20) { sleep 0.01 until worker.reap? }
        File.delete(File.join(root, "worker-00.#{channel}"))
        assert_raises(Errno::ENOENT) { captured_output(worker) }
      end
    end
  end

  def test_spawn_failure_remains_an_exception_for_the_test_coordinator
    Dir.mktmpdir('parallel failure ') do |root|
      worker = ProjectTools::ParallelProcess.new(root, [], id: 'worker-00', reports: false)
      assert_raises(Errno::ENOENT) { worker.start(['/missing-synthetic-command'], [], root: root) }
      assert_nil worker.pid
      assert_nil worker.status
    end
  end
end
